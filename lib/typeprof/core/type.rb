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

    def self.strip_array(s)
      s.start_with?("Array[") && s.end_with?("]") ? s[6..-2] || raise : s
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
        raise unless @args.is_a?(::Array)
      end

      attr_reader :mod, :args

      def base_type(_)
        self
      end

      def check_match(genv, changes, vtx)
        vtx.each_type do |other_ty|
          case other_ty
          when Instance
            ty = self
            while ty
              if ty.mod == other_ty.mod
                args_all_match = true
                ty.args.zip(other_ty.args) do |arg, other_arg|
                  unless arg.check_match(genv, changes, other_arg || Source.new)
                    args_all_match = false
                    break
                  end
                end
                return true if args_all_match
              end
              changes.add_depended_superclass(ty.mod)

              if other_ty.mod.module?
                return true if check_match_included_modules(genv, changes, ty, other_ty)
              end

              ty = genv.get_superclass_type(ty, changes, {})
            end
          end
        end
        return false
      end

      def check_match_included_modules(genv, changes, ty, other_ty)
        ty.mod.included_modules.each do |inc_decl, inc_mod|
          if inc_decl.is_a?(AST::SigIncludeNode) && inc_mod.type_params
            inc_ty = genv.get_instance_type(inc_mod, inc_decl.args, changes, {}, ty)
          else
            type_params = inc_mod.type_params.map {|ty_param| Source.new() } # TODO: better support
            inc_ty = Type::Instance.new(genv, inc_mod, type_params)
          end
          if inc_ty.mod == other_ty.mod
            args_all_match = true
            inc_ty.args.zip(other_ty.args) do |arg, other_arg|
              if other_arg && !arg.check_match(genv, changes, other_arg)
                args_all_match = false
                break
              end
            end
            return true if args_all_match
          end
          changes.add_depended_superclass(inc_ty.mod)

          return true if check_match_included_modules(genv, changes, inc_ty, other_ty)
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

      def splat_assign(genv, lefts, rest_elem, rights)
        edges = []
        state = :left
        j = nil
        @elems.each_with_index do |elem, i|
          case state
          when :left
            if i < lefts.size
              edges << [elem, lefts[i]]
            else
              break unless rest_elem
              state = :rest
              redo
            end
          when :rest
            if @elems.size - i > rights.size
              edges << [elem, rest_elem]
            else
              state = :right
              j = i
              redo
            end
          when :right
            edges << [elem, rights[i - j]]
          end
        end
        edges
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
        vtx.each_type do |other_ty|
          case other_ty
          when Record
            # Hash can match with Record if Hash has Symbol keys
            # and Hash value type can accept all Record field values
            key_ty = get_key
            val_ty = get_value

            # Check if this Hash has Symbol keys
            return false unless key_ty && Source.new(genv.symbol_type).check_match(genv, changes, key_ty)

            # Check if Hash value type contains all required types for Record fields
            other_ty.fields.each do |_key, field_val_vtx|
              # For each Record field, check if field type can match with Hash value type
              return false unless val_ty && field_val_vtx.check_match(genv, changes, val_ty)
            end

            return true
          end
        end

        # Fall back to base_type check for other cases
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

      def check_match(genv, changes, vtx)
        genv.proc_type.check_match(genv, changes, vtx)
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
        genv.obj_type # Is this ok?
      end

      def check_match(genv, changes, vtx)
        true # should implement a better support...
      end

      def show
        "var[#{ @name }]"
      end
    end

    class Record < Type
      #: (GlobalEnv, ::Hash[Symbol, Vertex], Instance) -> void
      def initialize(genv, fields, base_type)
        @fields = fields
        @base_type = base_type
        raise unless base_type.is_a?(Instance)
      end

      attr_reader :fields

      def get_value(key = nil)
        if key
          # Return specific field value if it exists
          @fields[key]
        elsif @fields.empty?
          # Empty record has no values
          nil
        else
          # Return union of all field values if no specific key
          @base_type.args[1]
        end
      end

      def base_type(genv)
        @base_type
      end

      def check_match(genv, changes, vtx)
        vtx.each_type do |other_ty|
          case other_ty
          when Record
            # Check if all fields match
            return false unless @fields.size == other_ty.fields.size
            @fields.each do |key, val_vtx|
              other_val_vtx = other_ty.fields[key]
              return false unless other_val_vtx
              return false unless val_vtx.check_match(genv, changes, other_val_vtx)
            end
            return true
          when Hash
            # Record can match with Hash only if the Hash has Symbol keys
            # and all record values can match with the Hash value type
            key_vtx = other_ty.get_key
            val_vtx = other_ty.get_value

            # Check if Hash key type is Symbol
            return false unless key_vtx && Source.new(genv.symbol_type).check_match(genv, changes, key_vtx)

            # Check if all record field values can match with Hash value type
            @fields.each do |_key, field_val_vtx|
              return false unless field_val_vtx.check_match(genv, changes, val_vtx)
            end

            return true
          end
        end
        return false
      end

      def show
        field_strs = @fields.map do |key, val_vtx|
          "#{ key }: #{ Type.strip_parens(val_vtx.show) }"
        end
        "{ #{ field_strs.join(", ") } }"
      end
    end
  end
end
