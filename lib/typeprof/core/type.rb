module TypeProf::Core
  class Type
    # This new method does memoize creation of types
    #: (GlobalEnv, *untyped) -> instance
    def self.new(genv, *args)
      genv.type_table[[self] + args] ||= super(genv, *args)
    end

    def self.strip_parens(s)
      #s =~ /\A\((.*)\)\z/ ? $1 : s
      s.start_with?("(") && s.end_with?(")") ? s[1..-2] || raise : s
    end

    def self.default_param_map(genv, ty)
      ty = ty.base_type(genv)
      instance_ty = ty.is_a?(Type::Instance) ? ty : Type::Instance.new(genv, ty.mod, []) # TODO: type params
      singleton_ty = ty.is_a?(Type::Instance) ? Type::Singleton.new(genv, ty.mod) : ty
      {
        "*self": Source.new(ty),
        "*instance": Source.new(instance_ty),
        "*class": Source.new(singleton_ty),
      }
    end

    class Singleton < Type
      #: (GlobalEnv, ModuleEntity) -> void
      def initialize(genv, mod)
        raise unless mod.is_a?(ModuleEntity)
        # TODO: type_param
        @mod = mod
      end

      attr_reader :mod

      def base_type(_)
        self
      end

      def check_match(genv, changes, vtx)
        vtx.each_type do |other_ty|
          case other_ty
          when Singleton
            other_mod = other_ty.mod
            if other_mod.module?
              # TODO: implement
            else
              mod = @mod
              while mod
                return true if mod == other_mod
                changes.add_depended_superclass(mod)
                mod = mod.superclass
              end
            end
          when Instance
            base_ty = @mod.module? ? genv.mod_type : genv.cls_type
            return true if base_ty.check_match(genv, changes, Source.new(other_ty))
          end
        end
        return false
      end

      def show
        "singleton(#{ @mod.show_cpath })"
      end

      def match?(genv, other)
        return true if self == other

        # TODO: implement!
        return false
      end

      def get_instance_type(genv)
        params = @mod.type_params
        Instance.new(genv, @mod, params ? params.map { Source.new } : [])
      end
    end

    class Instance < Type
      #: (GlobalEnv, ModuleEntity, ::Array[Vertex]) -> void
      def initialize(genv, mod, args)
        raise mod.class.to_s unless mod.is_a?(ModuleEntity)
        @mod = mod
        @args = args
      end

      attr_reader :mod, :args

      def base_type(_)
        self
      end

      def check_match(genv, changes, vtx)
        vtx.each_type do |other_ty|
          case other_ty
          when Instance
            other_mod = other_ty.mod
            mod = @mod
            args = @args
            while mod
              if mod == other_mod
                args_all_match = true
                args.zip(other_ty.args) do |arg, other_arg|
                  unless arg.check_match(genv, changes, other_arg)
                    args_all_match = false
                    break
                  end
                end
                return true if args_all_match
              end
              changes.add_depended_superclass(mod)

              super_mod = mod.superclass
              args2 = []
              if super_mod && super_mod.type_params
                subst2 = {}
                mod.type_params.zip(@args) do |param, vtx|
                  subst2[param] = vtx
                end
                super_mod.type_params.zip(mod.superclass_type_args || []) do |param, arg|
                  args2 << arg.covariant_vertex(genv, changes, subst2)
                end
              end
              mod = super_mod
              args = args2
            end
          end
        end
        return false
      end

      def show
        case @mod.cpath
        when [:NilClass] then "nil"
        when [:TrueClass] then "true"
        when [:FalseClass] then "false"
        else
          "#{ @mod.show_cpath }#{ @args.empty? ? "" : "[#{ @args.map {|arg| Type.strip_parens(arg.show) }.join(", ") }]" }"
        end
      end

      def match?(genv, other)
        return true if self == other

        # TODO: base_type?
        return Instance === other && genv.subclass?(@mod.cpath, other.mod.cpath)
      end
    end

    class Array < Type
      #: (GlobalEnv, ::Array[Vertex], Instance) -> void
      def initialize(genv, elems, base_type)
        @elems = elems
        @base_type = base_type
        raise unless base_type.is_a?(Instance)
      end

      attr_reader :elems

      def get_elem(genv, idx = nil)
        if idx && @elems
          @elems[idx] || Source.new(genv.nil_type)
        else
          @base_type.args.first
        end
      end

      def base_type(genv)
        @base_type
      end

      def check_match(genv, changes, vtx)
        vtx.each_type do |other_ty|
          if other_ty.is_a?(Array)
            if @elems.size == other_ty.elems.size
              match = true
              @elems.zip(other_ty.elems) do |elem, other_elem|
                unless elem.check_match(genv, changes, other_elem)
                  match = false
                  break
                end
              end
              return true if match
            end
          end
        end
        @base_type.check_match(genv, changes, vtx)
      end

      def show
        if @elems
          "[#{ @elems.map {|e| Type.strip_parens(e.show) }.join(", ") }]"
        else
          "#{ @base_type.mod.show_cpath }[#{ Type.strip_parens(@unified_elem.show) }]"
        end
      end
    end

    class Hash < Type
      #: (GlobalEnv, ::Array[Vertex], Instance) -> void
      def initialize(genv, literal_pairs, base_type)
        @literal_pairs = literal_pairs
        @base_type = base_type
        raise unless base_type.is_a?(Instance)
      end

      def get_key
        @base_type.args[0]
      end

      def get_value(key = nil)
        @literal_pairs[key] || @base_type.args[1]
      end

      def base_type(genv)
        @base_type
      end

      def check_match(genv, changes, vtx)
        # TODO: implement
        @base_type.check_match(genv, changes, vtx)
      end

      def show
        @base_type.show
      end
    end

    class Proc < Type
      def initialize(genv, block)
        @block = block
      end

      attr_reader :block

      def base_type(genv)
        genv.proc_type
      end

      def show
        "<Proc>"
      end
    end

    class Symbol < Type
      #: (GlobalEnv, ::Symbol) -> void
      def initialize(genv, sym)
        @sym = sym
      end

      attr_reader :sym

      def base_type(genv)
        genv.symbol_type
      end

      def check_match(genv, changes, vtx)
        vtx.each_type do |other_ty|
          case other_ty
          when Symbol
            return true if @sym == other_ty.sym
          when Instance
            return true if genv.symbol_type.check_match(genv, changes, Source.new(other_ty))
          end
        end
        return false
      end

      def show
        @sym.inspect
      end
    end

    class Bot < Type
      def initialize(genv)
      end

      def base_type(genv)
        genv.obj_type
      end

      def check_match(genv, changes, vtx)
        return true
      end

      def show
        "bot"
      end
    end

    class Var < Type
      #: (GlobalEnv, ::Symbol, Vertex) -> void
      def initialize(genv, name, vtx)
        @name = name
        @vtx = vtx
      end

      attr_reader :name, :vtx

      def base_type(genv)
        raise "unsupported"
      end

      def check_match(genv, changes, vtx)
        raise "unsupported"
      end

      def show
        "var[#{ @name }]"
      end
    end
  end
end