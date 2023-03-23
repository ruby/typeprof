module TypeProf::Core
  class Type
    def base_types(_)
      [self]
    end

    def self.strip_parens(s)
      s =~ /\A\((.*)\)\z/ ? $1 : s
    end

    class Module < Type
      include StructuralEquality

      def initialize(cpath)
        # TODO: type_param
        @cpath = cpath
      end

      attr_reader :cpath

      def show
        "singleton(#{ @cpath.empty? ? "Object" : @cpath.join("::" ) })"
      end

      def get_instance_type
        Instance.new(@cpath)
      end
    end

    class Instance < Type
      include StructuralEquality

      def initialize(cpath)
        raise unless cpath.is_a?(::Array)
        @cpath = cpath
      end

      attr_reader :cpath

      def get_class_type
        Class.new(:class, @cpath)
      end

      def show
        case @cpath
        when [:NilClass] then "nil"
        when [:TrueClass] then "true"
        when [:FalseClass] then "false"
        else
          "#{ @cpath.empty? ? "Object" : @cpath.join("::" )}"
        end
      end

      def match?(genv, other)
        return true if self == other

        # TODO: base_type?
        return Instance === other && genv.subclass?(@cpath, other.cpath)
      end
    end

    class Array < Type
      include StructuralEquality

      def initialize(elems, unified_elem, base_type)
        @elems = elems
        raise unless unified_elem
        @unified_elem = unified_elem
        @base_type = base_type
      end

      def get_elem(idx = nil)
        if idx && @elems
          @elems[idx] || Source.new(Type.nil)
        else
          @unified_elem
        end
      end

      def base_types(genv)
        [@base_type]
      end

      def show
        if @elems
          "[#{ @elems.map {|e| Type.strip_parens(e.show) }.join(", ") }]"
        else
          "Array[#{ Type.strip_parens(@unified_elem.show) }]"
        end
      end
    end

    class Hash < Type
      include StructuralEquality

      def initialize(literal_pairs, unified_key, unified_val)
        @literal_pairs = literal_pairs
        @unified_key = unified_key
        @unified_val = unified_val
      end

      def get_key
        @unified_key
      end

      def get_value(key = nil)
        @literal_pairs[key] || @unified_val
      end

      def base_types(genv)
        [Type::Instance.new([:Hash])]
      end

      def show
        "Hash[#{ Type.strip_parens(@unified_key.show) }, #{ Type.strip_parens(@unified_val.show) }]"
      end
    end

    class Proc < Type
      def initialize(block)
        @block = block
      end

      attr_reader :block

      def base_types(genv)
        [Type::Instance.new([:Proc])]
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
        [Type::Instance.new([:Symbol])]
      end

      def show
        @sym.inspect
      end
    end

    class RBS < Type
      include StructuralEquality

      def initialize(rbs_type)
        @rbs_type = rbs_type
      end

      attr_reader :rbs_type

      def base_types(genv)
        # XXX: We need to consider this
        map = {}
        vtxs = Signatures.type(genv, @rbs_type, map)
        vtxs.flat_map do |vtx|
          vtx.types.keys
        end.uniq
      end

      def inspect
        "#<Type::RBS ...>"
      end
    end

    def self.obj = Type::Instance.new([:Object])
    def self.nil = Type::Instance.new([:NilClass])
    def self.true = Type::Instance.new([:TrueClass])
    def self.false = Type::Instance.new([:FalseClass])
    def self.str = Type::Instance.new([:String])
    def self.int = Type::Instance.new([:Integer])
    def self.float = Type::Instance.new([:Float])
    def self.ary = Type::Instance.new([:Array])
  end
end