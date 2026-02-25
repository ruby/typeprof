module TypeProf::Core
  class AST
    class ModuleBaseNode < Node
      def initialize(raw_node, lenv, raw_cpath, meta, raw_scope, use_result)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref)
        @tbl = raw_node.locals

        # TODO: class Foo < Struct.new(:foo, :bar)

        if @static_cpath
          ncref = CRef.new(@static_cpath, meta ? :metaclass : :class, nil, lenv.cref)
          nlenv = LocalEnv.new(@lenv.file_context, ncref, {}, [])
          @body = raw_scope ? AST.create_node(raw_scope, nlenv, use_result) : DummyNilNode.new(code_range, lenv)
        else
          @body = nil
        end

        @cname_code_range = meta ? nil : lenv.code_range_from_node(raw_node.constant_path)
        @mod_cdef = nil
      end

      attr_reader :tbl, :cpath, :static_cpath, :cname_code_range, :body

      def subnodes = { cpath:, body: }
      def attrs = { static_cpath:, tbl: }

      def define0(genv)
        @cpath.define(genv)
        if @static_cpath
          mod = genv.resolve_cpath(@static_cpath)
          @mod_cdef = mod.add_module_def(genv, self)
          @body.define(genv)
        else
          kind = self.is_a?(ModuleNode) ? "module" : "class"
          @changes.add_diagnostic(:code_range, "TypeProf cannot analyze a non-static #{ kind }") # warning
          nil
        end
      end

      def define_copy(genv)
        if @static_cpath
          mod = genv.resolve_cpath(@static_cpath)
          @mod_cdef = mod.add_module_def(genv, self)
          mod.remove_module_def(genv, @prev_node)
        end
        super(genv)
      end

      def undefine0(genv)
        if @static_cpath
          mod = genv.resolve_cpath(@static_cpath)
          mod.remove_module_def(genv, self)
          @body.undefine(genv)
        end
        @cpath.undefine(genv)
      end

      def install0(genv)
        @cpath.install(genv)
        if @static_cpath
          @tbl.each {|var| @body.lenv.locals[var] = Source.new(genv.nil_type) }
          @body.lenv.locals[:"*self"] = @body.lenv.cref.get_self(genv)

          mod_val = Source.new(Type::Singleton.new(genv, genv.resolve_cpath(@static_cpath)))
          @changes.add_edge(genv, mod_val, @mod_cdef.vtx)
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
        super(raw_node, lenv, raw_node.constant_path, false, raw_node.body, use_result)
      end
    end

    class ClassNode < ModuleBaseNode
      def initialize(raw_node, lenv, use_result)
        super(raw_node, lenv, raw_node.constant_path, false, raw_node.body, use_result)
        raw_superclass = raw_node.superclass
        if raw_superclass
          # In Ruby, the superclass expression is evaluated before the class constant
          # is created. When the superclass is a bare constant with the same name as
          # the class being defined (e.g., `class Foo < Foo` inside a module), use the
          # outer scope to avoid resolving to the class itself.
          if @static_cpath && lenv.cref.outer &&
             raw_superclass.type == :constant_read_node &&
             raw_superclass.name == @static_cpath.last
            slenv = LocalEnv.new(lenv.file_context, lenv.cref.outer, {}, [])
            @superclass_cpath = AST.create_node(raw_superclass, slenv)
          else
            @superclass_cpath = AST.create_node(raw_superclass, lenv)
          end
        else
          @superclass_cpath = nil
        end
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
        if @static_cpath && @superclass_cpath
          const_read = @superclass_cpath.static_ret
          if const_read && const_read.cpath
            super_mod = genv.resolve_cpath(const_read.cpath)
            self_mod = genv.resolve_cpath(@static_cpath)
            mod = super_mod
            while mod
              if mod == self_mod
                @changes.add_diagnostic(:code_range, "circular inheritance", @superclass_cpath)
                break
              end
              mod = mod.superclass
            end
          end
        end
        super(genv)
      end
    end

    class SingletonClassNode < ModuleBaseNode
      def initialize(raw_node, lenv, use_result)
        super(raw_node, lenv, raw_node.expression, true, raw_node.body, use_result)
      end
    end
  end
end
