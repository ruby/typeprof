module TypeProf::Core
  class AST
    class SELF < Node
      def install0(genv)
        @lenv.get_self
      end
    end

    class LIT < Node
      def initialize(raw_node, lenv, lit)
        super(raw_node, lenv)
        @lit = lit
      end

      attr_reader :lit

      def attrs = { lit: }

      def install0(genv)
        case @lit
        when Integer
          Source.new(Type::Instance.new([:Integer]))
        when String
          Source.new(Type::Instance.new([:String]))
        when Float
          Source.new(Type::Instance.new([:Float]))
        when Symbol
          Source.new(Type::Symbol.new(@lit))
        when TrueClass
          Source.new(Type::Instance.new([:TrueClss]))
        when FalseClass
          Source.new(Type::Instance.new([:FalseClss]))
        else
          raise "not supported yet: #{ @lit.inspect }"
        end
      end

      def diff(prev_node)
        @lit.class == prev_node.lit.class && @lit == prev_node.lit && super
      end

      def dump0(dumper)
        @lit.inspect
      end
    end

    class LIST < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @elems = raw_node.children.compact.map {|n| AST.create_node(n, lenv) }
      end

      attr_reader :elems

      def subnodes
        h = {}
        @elems.each_with_index {|elem, i| h[i] = elem }
        h
      end

      def install0(genv)
        elems = @elems.map {|e| e.install(genv) }
        unified_elem = Vertex.new("ary-elems-unified", self)
        elems.each {|vtx| vtx.add_edge(genv, unified_elem) }
        Source.new(Type::Array.new(elems, unified_elem))
      end

      def diff(prev_node)
        if prev_node.is_a?(LIST) && @elems.size == prev_node.elems.size
          @elems.zip(prev_node.elems) do |elem, prev_elem|
            elem.diff(prev_elem)
            return unless elem.prev_node
          end
          @prev_node = prev_node
        end
      end

      def dump0(dumper)
        "[#{ @elems.map {|elem| elem.dump(dumper) }.join(", ") }]"
      end
    end
  end
end