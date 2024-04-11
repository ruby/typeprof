module TypeProf::Core
  class AST
    class ModuleBaseNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)
        @tbl = raw_node.locals

        # TODO: class Foo < Struct.new(:foo, :bar)

        if @static_cpath
          ncref = CRef.new(@static_cpath, true, nil, lenv.cref)
          nlenv = LocalEnv.new(@lenv.path, ncref, {})
          @body = raw_scope ? AST.create_node(raw_scope, nlenv) : DummyNilNode.new(code_range, lenv)
        else
          @body = nil
        end
      end

      attr_reader :tbl, :cpath, :static_cpath, :body

      def subnodes = { cpath:, body: }
      def attrs = { static_cpath:, tbl: }

      def define0(genv)
        @cpath.define(genv)
        if @static_cpath
          @body.define(genv)
          @mod = genv.resolve_cpath(@static_cpath)
          @mod_cdef = @mod.add_module_def(genv, self)
        else
          kind = self.is_a?(ModuleNode) ? "module" : "class"
          add_diagnostic("TypeProf cannot analyze a non-static #{ kind }") # warning
          nil
        end
      end

      def undefine0(genv)
        if @static_cpath
          @mod.remove_module_def(genv, self)
          @body.undefine(genv)
        end
        @cpath.undefine(genv)
      end

      def install0(genv)
        @cpath.install(genv)
        if @static_cpath
          @tbl.each {|var| @body.lenv.locals[var] = Source.new(genv.nil_type) }
          @body.lenv.locals[:"*self"] = Source.new(@body.lenv.cref.get_self(genv))
          @body.lenv.locals[:"*ret"] = Vertex.new("module_ret", self)

          @mod_val = Source.new(Type::Singleton.new(genv, genv.resolve_cpath(@static_cpath)))
          @mod_val.add_edge(genv, @mod_cdef.vtx)
          ret = Vertex.new("module_return", self)
          @body.install(genv).add_edge(genv, ret)
          @body.lenv.get_var(:"*ret").add_edge(genv, ret)
          ret
        else
          Source.new
        end
      end

      def uninstall0(genv)
        super(genv)
        if @static_cpath
          @mod_val.remove_edge(genv, @mod_cdef.vtx)
        end
      end

      def modified_vars(tbl, vars)
        # skip
      end
    end

    class ModuleNode < ModuleBaseNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, raw_node.constant_path, raw_node.body)
      end
    end

    class ClassNode < ModuleBaseNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, raw_node.constant_path, raw_node.body)
        raw_superclass = raw_node.superclass
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
        super(genv)
      end

      def undefine0(genv)
        super(genv)
        @superclass_cpath.undefine(genv) if @superclass_cpath
      end

      def install0(genv)
        @superclass_cpath.install(genv) if @superclass_cpath
        super(genv)
      end
    end
  end
end
