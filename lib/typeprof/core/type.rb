module TypeProf::Core
  class Type
    def base_types(_)
      [self]
    end

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

      def show
        "singleton(#{ @mod.show_cpath })"
      end

      def match?(genv, other)
        return true if self == other

        # TODO: implement!
        return false
      end

      def get_instance_type(genv)
        Instance.new(genv, @mod, []) # Is this okay?
      end
    end

    class Instance < Type
      include StructuralEquality

      def initialize(mod, args)
        raise unless mod.is_a?(ModuleEntity)
        @mod = mod
        @args = args
      end

      attr_reader :mod, :args

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
      end

      def get_elem(genv, idx = nil)
        if idx && @elems
          @elems[idx] || Source.new(genv.nil_type)
        else
          @base_type.args.first
        end
      end

      def base_types(genv)
        [@base_type]
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
      end

      def get_key
        @base_type.args[0]
      end

      def get_value(key = nil)
        @literal_pairs[key] || @base_type.args[1]
      end

      def base_types(genv)
        [@base_type]
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

      def base_types(genv)
        [genv.proc_type]
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

      def base_types(genv)
        [genv.symbol_type]
      end

      def show
        @sym.inspect
      end
    end

    class Bot < Type
      include StructuralEquality

      def base_types(genv)
        [genv.obj_type]
      end

      def show
        "bot"
      end
    end
  end
end