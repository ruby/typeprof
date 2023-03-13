module TypeProf
  class Type
    def base_type(_)
      self
    end

    class Module < Type
      include StructuralEquality

      def initialize(cpath)
        # TODO: type_param
        @cpath = cpath
      end

      attr_reader :cpath

      def show
        "singleton(#{ @cpath.join("::" ) })"
      end
    end

    class Class < Module
      include StructuralEquality

      def initialize(cpath)
        # TODO: type_param
        @cpath = cpath
      end

      attr_reader :kind, :cpath

      def get_instance_type
        raise "cannot instantiate a module" if @kind == :module
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
        "#{ @cpath.join("::" )}"
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

      def base_type(genv)
        Type::Instance.new([:Array])
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

      def base_type(genv)
        Type::Instance.new([:Proc])
      end

      def show
        "<Proc>"
      end
    end

    class RBS < Type
      include StructuralEquality

      def initialize(rbs_type)
        @rbs_type = rbs_type
      end

      attr_reader :rbs_type

      def base_type(genv)
        Signatures.type(genv, @rbs_type)
      end

      def inspect
        "#<Type::RBS ...>"
      end
    end
  end
end
