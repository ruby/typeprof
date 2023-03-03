module TypeProf
  class Type
    include StructuralEquality

    class Untyped < Type
      def inspect
        "<untyped>"
      end
    end

    class Module < Type
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
      def initialize(cpath)
        raise unless cpath.is_a?(Array)
        @cpath = cpath
      end

      attr_reader :cpath

      def get_class_type
        Class.new(:class, @cpath)
      end

      def show
        "#{ @cpath.join("::" )}"
      end
    end

    class RBS < Type
      def initialize(rbs_type)
        @rbs_type = rbs_type
      end

      attr_reader :rbs_type

      def rbs_expand(genv)
        Signatures.type(genv, @rbs_type)
      end

      def inspect
        "#<Type::RBS ...>"
      end
    end
  end
end
