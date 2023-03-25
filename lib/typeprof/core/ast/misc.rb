module TypeProf::Core
  class AST
    class DEFINED < Node
      def initialize(raw_node, lenv)
        super
        raw_arg, = raw_node.children
        @arg = AST.create_node(raw_arg, lenv)
      end

      attr_reader :arg

      def subnodes = {} # no arg!

      def install0(genv)
        Source.new(Type.true, Type.false)
      end

      def diff(_)
      end

      def dump0(dumper)
        "defined?(#{ @arg.dump(dumper) })"
      end
    end
  end
end