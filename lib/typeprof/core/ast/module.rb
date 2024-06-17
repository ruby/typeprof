module TypeProf::Core
  class AST
    class ModuleBaseNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope, use_result)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)
        @tbl = raw_node.locals

        # TODO: class Foo < Struct.new(:foo, :bar)

        if @static_cpath
          ncref = CRef.new(@static_cpath, true, nil, lenv.cref)
          nlenv = LocalEnv.new(@lenv.path, ncref, {}, [], nil)
          @body = raw_scope ? AST.create_node(raw_scope, nlenv, use_result) : DummyNilNode.new(code_range, lenv)
        else
          @body = nil
        end

        @cname_code_range = TypeProf::CodeRange.from_node(raw_node.constant_path)
      end

      attr_reader :tbl, :cpath, :static_cpath, :cname_code_range, :body

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
          @changes.add_diagnostic(:code_range, "TypeProf cannot analyze a non-static #{ kind }") # warning
          nil
        end
      end

      def define_copy(genv)
        if @static_cpath
          @mod_cdef.add_def(self)
          @mod_cdef.remove_def(@prev_node)
        end
        super(genv)
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

          @mod_val = Source.new(Type::Singleton.new(genv, genv.resolve_cpath(@static_cpath)))
          @changes.add_edge(genv, @mod_val, @mod_cdef.vtx)
          ret = Vertex.new(self)
          @changes.add_edge(genv, @body.install(genv), ret)
          ret
        else
          Source.new
        end
      end

      def modified_vars(tbl, vars)
        # skip
      end
    end

    class ModuleNode < ModuleBaseNode
      def initialize(raw_node, lenv, use_result)
        super(raw_node, lenv, raw_node.constant_path, raw_node.body, use_result)
      end
    end

    class ClassNode < ModuleBaseNode
      def initialize(raw_node, lenv, use_result)
        super(raw_node, lenv, raw_node.constant_path, raw_node.body, use_result)
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

    class SingletonClassNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)

        @expression = AST.create_node(raw_node.expression, lenv)
        @tbl = raw_node.locals

        @static_cpath = case @expression
                        when ConstantReadNode
                          AST.parse_cpath(@raw_node.expression, lenv.cref.cpath)
                        when SelfNode
                          lenv.cref.cpath
                        else
                          raise "unsupported expression: #{@expression}"
                        end

        if @static_cpath.nil? || @static_cpath.empty?
          @body = nil
        else
          ncref = CRef.new(static_cpath, true, nil, lenv.cref)
          nlenv = LocalEnv.new(lenv.path, ncref, {}, [], ncref)
          @body = @raw_node.body ? AST.create_node(@raw_node.body, nlenv) : DummyNilNode.new(code_range, lenv)
        end
      end

      attr_reader :expression, :tbl, :static_cpath, :body

      def subnodes = { expression:, body: }
      def attrs = { tbl:, static_cpath: }

      def define0(genv)
        @expression.define(genv)

        if @body
          @body.define(genv)
          @mod = genv.resolve_cpath(@static_cpath)
          @mod_cdef = @mod.add_module_def(genv, self)
        else
          @changes.add_diagnostic(:code_range, "TypeProf cannot analyze a non-static class") # warning
          nil
        end
      end

      def define_copy(genv)
        if @body
          @mod_cdef.add_def(self)
          @mod_cdef.remove_def(@prev_node)
        end
        super(genv)
      end

      def undefine0(genv)
        if @body
          @mod.remove_module_def(genv, self)
          @body.undefine(genv)
        end

        @expression.undefine(genv)
      end

      def install0(genv)
        @expression.install(genv)

        if @body
          @tbl.each {|var| @body.lenv.locals[var] = Source.new(genv.nil_type) }
          @body.lenv.locals[:"*self"] = Source.new(@body.lenv.cref.get_self(genv))

          @mod_val = Source.new(Type::Singleton.new(genv, genv.resolve_cpath(@static_cpath)))
          @changes.add_edge(genv, @mod_val, @mod_cdef.vtx)
          ret = Vertex.new(self)
          @changes.add_edge(genv, @body.install(genv), ret)
          ret
        else
          Source.new
        end
      end

      def modified_vars(tbl, vars)
        # skip
      end
    end
  end
end
