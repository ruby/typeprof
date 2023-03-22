module TypeProf::Core
  class AST
    class BLOCK < Node
      def initialize(raw_node, lenv)
        super
        stmts = raw_node.children
        @stmts = stmts.map {|n| AST.create_node(n, lenv) }
      end

      attr_reader :stmts

      def subnodes
        h = {}
        @stmts.each_with_index {|stmt, i| h[i] = stmt }
        h
      end

      def install0(genv)
        ret = nil
        @stmts.each do |stmt|
          ret = stmt.install(genv)
        end
        ret || Source.new(Type::Instance.new([:NilClass]))
      end

      def diff(prev_node)
        if prev_node.is_a?(BLOCK)
          i = 0
          while i < @stmts.size
            @stmts[i].diff(prev_node.stmts[i])
            if !@stmts[i].prev_node
              j1 = @stmts.size - 1
              j2 = prev_node.stmts.size - 1
              while j1 >= i
                @stmts[j1].diff(prev_node.stmts[j2])
                if !@stmts[j1].prev_node
                  return
                end
                j1 -= 1
                j2 -= 1
              end
              return
            end
            i += 1
          end
          if i == prev_node.stmts.size
            @prev_node = prev_node
          end
        end
      end

      def dump0(dumper)
        @stmts.map do |stmt|
          stmt.dump(dumper)
        end.join("\n")
      end
    end

    class ModuleNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)

        # TODO: class Foo < Struct.new(:foo, :bar)

        if @static_cpath
          raise unless raw_scope.type == :SCOPE
          _tbl, args, raw_body = raw_scope.children
          raise unless args == nil

          ncref = CRef.new(@static_cpath, true, lenv.cref)
          nlenv = LexicalScope.new(lenv.text_id, self, ncref, nil)
          @body = AST.create_node(raw_body, nlenv)
        else
          @body = nil
        end
      end

      attr_reader :cpath, :static_cpath, :body

      def subnodes = { cpath:, body: }
      def attrs = { static_cpath: }
    end

    class MODULE < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
      end

      def install0(genv)
        @cpath.install(genv)
        if @static_cpath
          genv.add_module(@static_cpath, self, nil)

          val = Source.new(Type::Module.new(@static_cpath))
          cdef = ConstDef.new(@static_cpath[0..-2], @static_cpath[-1], self, val)
          add_def(genv, cdef)

          ret = @body.lenv.get_ret
          @body.install(genv).add_edge(genv, ret)
          ret
        else
          # TODO: show error
          check
        end
      end

      def uninstall0(genv)
        if @static_cpath && @static_superclass_cpath
          genv.remove_module(@static_cpath, self)
        end
        super
      end

      def dump0(dumper)
        s = "module #{ @cpath.join("::") }\n" + s.gsub(/^/, "  ") + "\n"
        if @static_cpath
          s << @body.dump(dumper).gsub(/^/, "  ") + "\n"
        else
          s << "<analysis ommitted>\n"
        end
        s << "end"
      end
    end

    class CLASS < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_superclass, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
        if raw_superclass
          @superclass_cpath = AST.create_node(raw_superclass, lenv)
          @static_superclass_cpath = AST.parse_cpath(raw_superclass, lenv.cref.cpath)
          @body = nil unless @static_superclass_cpath
        else
          @superclass_cpath = nil
          @static_superclass_cpath = [:Object]
        end
      end

      attr_reader :superclass_cpath, :static_superclass_cpath

      def subnodes
        super.merge!({ superclass_cpath: })
      end

      def attrs
        super.merge!({ static_superclass_cpath: })
      end

      def install0(genv)
        @cpath.install(genv)
        @superclass_cpath.install(genv) if @superclass_cpath
        if @static_cpath && @static_superclass_cpath
          genv.add_module(@static_cpath, self, @static_superclass_cpath)

          val = Source.new(Type::Module.new(@static_cpath))
          cdef = ConstDef.new(@static_cpath[0..-2], @static_cpath[-1], self, val)
          add_def(genv, cdef)

          ret = @body.lenv.get_ret
          @body.install(genv).add_edge(genv, ret)
          ret
        else
          # TODO: show error
          check
        end
      end

      def uninstall0(genv)
        if @static_cpath && @static_superclass_cpath
          genv.remove_module(@static_cpath, self)
        end
        super
      end

      def dump0(dumper)
        s = "class #{ @cpath.dump(dumper) }"
        s << " < #{ @superclass_cpath.dump(dumper) }" if @superclass_cpath
        s << "\n"
        if @static_cpath
          s << @body.dump(dumper).gsub(/^/, "  ") + "\n"
        else
          s << "<analysis ommitted>\n"
        end
        s << "end"
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
        @body_lenv = LexicalScope.new(lenv.text_id, self, ncref, nil)
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
              f_args << @body_lenv.def_var(@tbl[i], self)
            end
            blk_idx = @args[9]
            block = blk_idx ? @body_lenv.def_var(blk_idx, self) : nil
          end
          ret = @body_lenv.get_ret
          if @body
            body_ret = @body.install(genv)
          else
            body_ret = Source.new(Type::Instance.new([:NilClass]))
          end
          body_ret.add_edge(genv, ret)
          mdef = MethodDef.new(@lenv.cref.cpath, @singleton, @mid, self, f_args, block, ret)
          add_def(genv, mdef)
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
          (0...@args[0]).map {|i| "#{ @tbl[i] }:\e[34m:#{ @body_lenv.get_var(@tbl[i]) }\e[m" }.join(", ")
        })\n"
        s << @body.dump(dumper).gsub(/^/, "  ") + "\n"
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

    class BEGIN_ < Node
      def initialize(raw_node, lenv)
        super
        raise NotImplementedError if raw_node.children != [nil]
      end

      def install0(genv)
        # TODO
        Vertex.new("begin", self)
      end

      def uninstall0(genv)
        # TODO
      end

      def diff(prev_node)
        # TODO
      end

      def dump0(dumper)
        "begin; end"
      end
    end
  end
end