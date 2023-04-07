module TypeProf::Core
  class AST
    class SIG_TY_BASE_BOOL < Node
      def install0(genv)
        Source.new(genv.true_type, genv.false_type)
      end
    end

    class SIG_TY_BASE_NIL < Node
      def install0(genv)
        Source.new(genv.nil_type)
      end
    end

    class SIG_TY_BASE_SELF < Node
      def install0(genv)
        Source.new(Type::Self.new)
      end
    end

    class SIG_TY_BASE_VOID < Node
      def install0(genv)
        Source.new(genv.obj_type) # TODO
      end
    end

    class SIG_TY_BASE_ANY < Node
      def install0(genv)
        Source.new() # TODO
      end
    end

    class SIG_TY_BASE_TOP < Node
      def install0(genv)
        Source.new() # TODO
      end
    end

    class SIG_TY_BASE_BOTTOM < Node
      def install0(genv)
        Source.new(Type::Bot.new) # TODO
      end
    end

    class SIG_TY_BASE_INSTANCE < Node
      def install0(genv)
        Source.new() # TODO
      end
    end

    class SIG_TY_ALIAS < Node
      def install0(genv)
        Source.new() # TODO
        cref0 = cref
        while cref0
          tae = genv.resolve_type_alias(cref0.cpath + type.name.namespace.path, type.name.name)
          break if tae.exist?
          cref0 = cref0.outer
        end
        if tae.exist?
          rbs_type_to_vtx0(genv, node, tae.decls.to_a.first.rbs_type, vtx, param_map, cref)
        else
          p "???"
          pp type.name
          Source.new # ???
        end
      end
    end

    class SIG_TY_UNION < Node
      def initialize(raw_decl, lenv)
        super
        @types = raw_decl.types.map {|type| AST.create_rbs_type(type, lenv) }
      end

      attr_reader :types

      def subnodes = { types: }
    end

    class SIG_TY_INTERSECTION < Node
    end

    class SIG_TY_MODULE < Node
    end

    class SIG_TY_INSTANCE < Node
    end

    class SIG_TY_TUPLE < Node
    end

    class SIG_TY_VAR < Node
    end

    class SIG_TY_OPTIONAL < Node
    end

    class SIG_TY_LITERAL < Node
    end

    class SIG_TY_PARAM < Node
    end

    class SIG_TY_PROC < Node
    end

    class SIG_TY_INTERFACE < Node
    end
  end
end