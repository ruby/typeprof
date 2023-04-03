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
          dir.add_module_def(genv, self)
          @body.define(genv)
          dir = genv.resolve_const(@static_cpath)
          dir.defs << self
          dir
        else
          kind = self.is_a?(MODULE) ? "module" : "class"
          add_diagnostic("TypeProf cannot analyze a non-static #{ kind }") # warning
          nil
        end
      end

      def undefine0(genv)
        if @static_cpath
          genv.resolve_const(@static_cpath).defs.delete(self)
          @body.undefine(genv)
          dir = genv.resolve_cpath(@static_cpath)
          dir.remove_module_def(genv, self)
        end
        @cpath.undefine(genv)
      end

      def install0(genv)
        @cpath.install(genv)
        if @static_cpath
          val = Source.new(Type::Module.new(@static_cpath))
          val.add_edge(genv, @static_ret.vtx)
          ret = Vertex.new("module_return", self)
          @body.install(genv).add_edge(genv, ret)
          @body.lenv.get_var(:"*ret").add_edge(genv, ret)
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
          const.followers << genv.resolve_cpath(@static_cpath) if const
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
  end
end