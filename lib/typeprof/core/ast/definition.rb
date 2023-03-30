module TypeProf::Core
  class AST
    class ModuleNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)

        # TODO: class Foo < Struct.new(:foo, :bar)

        if @static_cpath
          raise unless raw_scope.type == :SCOPE
          tbl, args, raw_body = raw_scope.children
          raise unless args == nil

          ncref = CRef.new(@static_cpath, true, lenv.cref)
          locals = {}
          tbl.each {|var| locals[var] = Source.new(Type.nil) }
          locals[:"*self"] = Source.new(ncref.get_self)
          locals[:"*ret"] = Vertex.new("module_ret", self)
          nlenv = LocalEnv.new(@lenv.path, ncref, locals)
          @body = AST.create_node(raw_body, nlenv)
        else
          @body = nil
        end
      end

      attr_reader :cpath, :static_cpath, :body

      def subnodes = { cpath:, body: }
      def attrs = { static_cpath: }

      def define0(genv)
        @cpath.define(genv)
        if @static_cpath
          dir = genv.resolve_cpath(@static_cpath)
          genv.add_define_queue(@static_cpath[0..-2]) if dir.module_defs.empty?
          dir.module_defs << self
          @body.define(genv)
          genv.resolve_const(@static_cpath).add_def(self)
        else
          kind = self.is_a?(MODULE) ? "module" : "class"
          add_diagnostics("TypeProf cannot analyze a non-static #{ kind }") # warning
          nil
        end
      end

      def undefine0(genv)
        if @static_cpath
          genv.resolve_const(@static_cpath).remove_def(self)
          @body.undefine(genv)
          dir = genv.resolve_cpath(@static_cpath)
          dir.module_defs.delete(self)
          genv.add_define_queue(@static_cpath[0..-2]) if dir.module_defs.empty?
        end
        @cpath.undefine(genv)
      end

      def install0(genv)
        @cpath.install(genv)
        if @static_cpath
          val = Source.new(Type::Module.new(@static_cpath))
          val.add_edge(genv, @static_ret.vtx)
          ret = @body.lenv.get_var(:"*ret")
          @body.install(genv).add_edge(genv, ret)
          ret
        else
          Source.new
        end
      end

      def dump_module(dumper, kind, superclass)
        s = "#{ kind } #{ @cpath.dump(dumper) }#{ superclass }\n"
        if @static_cpath
          s << @body.dump(dumper).gsub(/^/, "  ") + "\n"
        else
          s << "<analysis ommitted>\n"
        end
        s << "end"
      end
    end

    class MODULE < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
      end

      def dump0(dumper)
        dump_module(dumper, "module", "")
      end
    end

    class CLASS < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_superclass, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
        @superclass_cpath = raw_superclass ? AST.create_node(raw_superclass, lenv) : nil
      end

      attr_reader :superclass_cpath

      def subnodes
        super.merge!({ superclass_cpath: })
      end

      def define0(genv)
        if @static_cpath && @superclass_cpath
          const = @superclass_cpath.define(genv)
          const.const_reads << @static_cpath if const
        end
        super
      end

      def undefine0(genv)
        super
        @superclass_cpath.undefine(genv) if @superclass_cpath
      end

      def install0(genv)
        @superclass_cpath.install(genv) if @superclass_cpath
        super
      end

      def dump0(dumper)
        dump_module(dumper, "class", @superclass_cpath ? " < #{ @superclass_cpath.dump(dumper) }" : "")
      end
    end

    class DefNode < Node
      def initialize(raw_node, lenv, singleton, mid, raw_scope)
        super(raw_node, lenv)

        @singleton = singleton
        @mid = mid

        raise unless raw_scope.type == :SCOPE
        @tbl, raw_args, raw_body = raw_scope.children

        # TODO: default expression for optional args
        @args = raw_args.children

        ncref = CRef.new(lenv.cref.cpath, @singleton, lenv.cref)
        locals = {}
        @tbl.each {|var| locals[var] = Source.new(Type.nil) }
        locals[:"*self"] = Source.new(ncref.get_self)
        locals[:"*ret"] = Vertex.new("method_ret", self)
        @body_lenv = LocalEnv.new(@lenv.path, ncref, locals)
        @body = raw_body ? AST.create_node(raw_body, @body_lenv) : nil

        @args_code_ranges = []
        @args[0].times do |i|
          pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
          @args_code_ranges << AST.find_sym_code_range(pos, @tbl[i])
        end

        @reused = false
      end

      attr_reader :singleton, :mid, :tbl, :args, :body, :body_lenv

      def subnodes = @reused ? {} : { body: }
      def attrs = { singleton:, mid:, tbl:, args:, body_lenv: }

      attr_accessor :reused

      def install0(genv)
        if @prev_node
          reuse
          @prev_node.reused = true
        else
          # TODO: ユーザ定義 RBS があるときは検証する
          f_args = []
          block = nil
          if @args
            @args[0].times do |i|
              f_args << @body_lenv.new_var(@tbl[i], self)
            end
            # &block
            block = @body_lenv.new_var(:"*given_block", self)
            @body_lenv.set_var(@args[9], block) if @args[9]
          end
          ret = @body_lenv.get_var(:"*ret")
          if @body
            body_ret = @body.install(genv)
          else
            body_ret = Source.new(Type.nil)
          end
          body_ret.add_edge(genv, ret)
          mdef = MethodDef.new(self, f_args, block, ret)
          add_method_def(genv, @lenv.cref.cpath, @singleton, @mid, mdef)
        end
        Source.new(Type::Symbol.new(@mid))
      end

      def hover(pos)
        @args_code_ranges.each_with_index do |cr, i|
          if cr.include?(pos)
            yield DummySymbolNode.new(@tbl[i], cr, @body_lenv.get_var(@tbl[i]))
            break
          end
        end
        super
      end

      def dump0(dumper)
        s = "def #{ @mid }(#{
          (0..@args[0]-1).map {|i| "#{ @tbl[i] }:\e[34m:#{ @body_lenv.get_var(@tbl[i]) }\e[m" }.join(", ")
        })\n"
        s << @body.dump(dumper).gsub(/^/, "  ") + "\n" if @body
        s << "end"
      end
    end

    class DEFN < DefNode
      def initialize(raw_node, lenv)
        mid, raw_scope = raw_node.children
        super(raw_node, lenv, false, mid, raw_scope)
      end
    end

    class DEFS < DefNode
      def initialize(raw_node, lenv)
        raw_recv, mid, raw_scope = raw_node.children
        @recv = AST.create_node(raw_recv, lenv)
        unless @recv.is_a?(SELF)
          puts "???"
        end
        super(raw_node, lenv, true, mid, raw_scope)
      end
    end

    class ALIAS < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        raw_new_mid, raw_old_mid = raw_node.children
        @new_mid = AST.create_node(raw_new_mid, lenv)
        @old_mid = AST.create_node(raw_old_mid, lenv)
      end

      attr_reader :new_name, :old_name

      def subnodes = { new_name:, old_name: }

      def install0(genv)
        @new_mid.install(genv)
        @old_mid.install(genv)
        if @new_mid.is_a?(LIT) && @old_mid.is_a?(LIT)
          new_mid = @new_mid.lit
          old_mid = @old_mid.lit
          genv.resolve_meth(@lenv.cref.cpath, false, new_mid).add_alias(old_mid)
        end
        Source.new(Type.nil)
      end

      def uninstall0(genv)
        if @new_mid.is_a?(LIT) && @old_mid.is_a?(LIT)
          new_mid = @new_mid.lit
          old_mid = @old_mid.lit
          genv.resolve_meth(@lenv.cref.cpath, false, new_mid).remove_alias(old_mid)
        end
        super
      end

      def dump0(dumper)
        "alias #{ @new_name.dump(dumper) } #{ @old_name.dump(dumper) }"
      end
    end
  end
end