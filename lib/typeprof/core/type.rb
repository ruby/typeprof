module TypeProf::Core
  class Type
    def self.strip_parens(s)
      #s =~ /\A\((.*)\)\z/ ? $1 : s
      s.start_with?("(") && s.end_with?(")") ? s[1..-2] : s
    end

    class Singleton < Type
      include StructuralEquality

      def initialize(mod)
        raise unless mod.is_a?(ModuleEntity)
        # TODO: type_param
        @mod = mod
      end

      attr_reader :mod

      def base_type(_)
        self
      end

      def check_match(genv, changes, subst, vtx)
        vtx.types.each do |other_ty, _source|
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
            return true if base_ty.check_match(genv, changes, subst, Source.new(other_ty))
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
      include StructuralEquality

      def initialize(mod, args)
        raise mod.class.to_s unless mod.is_a?(ModuleEntity)
        @mod = mod
        @args = args
      end

      attr_reader :mod, :args

      def base_type(_)
        self
      end

      def check_match(genv, changes, subst, vtx)
        vtx.types.each do |other_ty, _source|
          case other_ty
          when Instance
            other_mod = other_ty.mod
            if other_mod.module?
              # TODO: implement
            else
              mod = @mod
              while mod
                if mod == other_mod
                  args_all_match = true
                  # TODO: other_args need to be handled more correctly
                  @args.zip(other_ty.args) do |arg, other_arg|
                    unless arg.check_match(genv, changes, subst, other_arg)
                      args_all_match = false
                      break
                    end
                  end
                  return true if args_all_match
                end
                changes.add_depended_superclass(mod)
                mod = mod.superclass
              end
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
      include StructuralEquality

      def initialize(elems, base_type)
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

      def check_match(genv, changes, subst, vtx)
        vtx.types.each do |other_ty, _source|
          if other_ty.is_a?(Array)
            if @elems.size == other_ty.elems.size
              match = true
              @elems.zip(other_ty.elems) do |elem, other_elem|
                unless elem.check_match(genv, changes, subst, other_elem)
                  match = false
                  break
                end
              end
              return true if match
            end
          end
        end
        @base_type.check_match(genv, changes, subst, vtx)
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
      include StructuralEquality

      def initialize(literal_pairs, base_type)
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

      def check_match(genv, changes, subst, vtx)
        # TODO: implement
        @base_type.check_match(genv, changes, subst, vtx)
      end

      def show
        @base_type.show
      end
    end

    class Proc < Type
      def initialize(block)
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
      include StructuralEquality

      def initialize(sym)
        @sym = sym
      end

      attr_reader :sym

      def base_type(genv)
        genv.symbol_type
      end

      def check_match(genv, changes, subst, vtx)
        vtx.types.each do |other_ty, _source|
          case other_ty
          when Symbol
            return true if @sym == other_ty.sym
          when Instance
            return true if genv.symbol_type.check_match(genv, changes, subst, Source.new(other_ty))
          end
        end
        return false
      end

      def show
        @sym.inspect
      end
    end

    class Bot < Type
      include StructuralEquality

      def base_type(genv)
        genv.obj_type
      end

      def check_match(genv, changes, subst, vtx)
        return true
      end

      def show
        "bot"
      end
    end

    class Var < Type
      include StructuralEquality

      def initialize(name, vtx)
        @name = name
        @vtx = vtx
      end

      attr_reader :name, :vtx

      def base_type(genv)
        raise "unsupported"
      end

      def check_match(genv, changes, subst, vtx)
        raise "unsupported"
      end

      def show
        "var[#{ @name }]"
      end
    end
  end
end