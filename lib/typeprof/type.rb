module TypeProf
  class Type
    def base_types(_)
      [self]
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
        "#{ @cpath.empty? ? "Object" : @cpath.join("::" )}"
      end

      def match?(genv, other)
        return true if self == other

        # TODO: base_type?
        return Instance === other && genv.subclass?(@cpath, other.cpath)
      end
    end

    class Array < Type
      include StructuralEquality

      def initialize(elem)
        @elem = elem
      end

      attr_reader :elem

      def base_types(genv)
        [Type::Instance.new([:Array])]
      end

      def show
        "Array[#{ @elem.show }]"
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
        map = {} # is this OK?
        Signatures.type(genv, @rbs_type, map)
      end

      def inspect
        "#<Type::RBS ...>"
      end
    end
  end
end
