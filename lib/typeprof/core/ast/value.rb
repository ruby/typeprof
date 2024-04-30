module TypeProf::Core
  class AST
    class SelfNode < Node
      def install0(genv)
        @lenv.get_var(:"*self")
      end
    end

    class LiteralNode < Node
      def initialize(raw_node, lenv, lit)
        super(raw_node, lenv)
        @lit = lit
      end

      attr_reader :lit

      def attrs = { lit: }

      def install0(genv)
        raise "not supported yet: #{ @lit.inspect }"
      end

      def diff(prev_node)
        # Need to compare their classes to distinguish between 1 and 1.0 (or use equal?)
        if prev_node.is_a?(LiteralNode) && @lit.class == prev_node.lit.class && @lit == prev_node.lit
          @prev_node = prev_node
        end
      end
    end

    class NilNode < LiteralNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, nil)
      end

      def install0(genv) = Source.new(genv.nil_type)
    end

    class TrueNode < LiteralNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, true)
      end

      def install0(genv) = Source.new(genv.true_type)
    end

    class FalseNode < LiteralNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, false)
      end

      def install0(genv) = Source.new(genv.false_type)
    end

    class IntegerNode < LiteralNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, Integer(raw_node.slice))
      end

      def install0(genv) = Source.new(genv.int_type)
    end

    class FloatNode < LiteralNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, Float(raw_node.slice))
      end

      def install0(genv) = Source.new(genv.float_type)
    end

    class SymbolNode < LiteralNode
      def initialize(raw_node, lenv)
        super(raw_node, lenv, raw_node.value.to_sym)
      end

      def install0(genv) = Source.new(Type::Symbol.new(genv, @lit))
    end

    class StringNode < LiteralNode
      def initialize(raw_node, lenv, content)
        super(raw_node, lenv, content)
      end

      def install0(genv) = Source.new(genv.str_type)
    end

    class InterpolatedStringNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @parts = []
        raw_node.parts.each do |raw_part|
          case raw_part.type
          when :string_node
            @parts << AST.create_node(raw_part, lenv)
          when :embedded_statements_node
            @parts << AST.create_node(raw_part.statements, lenv)
          else
            raise "unknown string part: #{ raw_part.type }"
          end
        end
      end

      attr_reader :parts

      def subnodes = { parts: }

      def install0(genv)
        @parts.each do |subnode|
          subnode.install(genv)
        end
        Source.new(genv.str_type)
      end

      def diff(prev_node)
        if prev_node.is_a?(InterpolatedStringNode) && @parts.size == prev_node.parts.size
          @parts.zip(prev_node.parts) do |n, prev_n|
            n.diff(prev_n)
            return unless n.prev_node
          end
          @prev_node = prev_node
        end
      end
    end

    class RegexpNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
      end

      def install0(genv) = Source.new(genv.regexp_type)
    end

    class InterpolatedRegexpNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @parts = []
        raw_node.parts.each do |raw_part|
          case raw_part.type
          when :string_node
            @parts << AST.create_node(raw_part, lenv)
          when :embedded_statements_node
            @parts << AST.create_node(raw_part.statements, lenv)
          else
            raise "unknown regexp part: #{ raw_part.type }"
          end
        end
      end

      attr_reader :parts

      def subnodes = { parts: }

      def install0(genv)
        @parts.each do |subnode|
          subnode.install(genv)
        end
        Source.new(genv.regexp_type)
      end

      def diff(prev_node)
        if prev_node.is_a?(InterpolatedRegexpNode) && @parts.size == prev_node.parts.size
          @parts.zip(prev_node.parts) do |n, prev_n|
            n.diff(prev_n)
            return unless n.prev_node
          end
          @prev_node = prev_node
        end
      end
    end

    class RangeNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @begin = raw_node.left ? AST.create_node(raw_node.left, lenv) : DummyNilNode.new(raw_node, lenv)
        @end = raw_node.right ? AST.create_node(raw_node.right, lenv) : DummyNilNode.new(raw_node, lenv)
      end

      attr_reader :begin, :end

      def subnodes = { begin:, end: }

      def install0(genv)
        elem = Vertex.new("range-elem", self)
        @changes.add_edge(genv, @begin.install(genv), elem)
        @changes.add_edge(genv, @end.install(genv), elem)
        Source.new(genv.gen_range_type(elem))
      end
    end

    class ArrayNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @elems = raw_node.elements.map {|n| AST.create_node(n, lenv) }
      end

      attr_reader :elems

      def subnodes = { elems: }

      def install0(genv)
        elems = @elems.map {|e| e.install(genv).new_vertex(genv, "ary-elem", self) }
        unified_elem = Vertex.new("ary-elems-unified", self)
        elems.each {|vtx| @changes.add_edge(genv, vtx, unified_elem) }
        Source.new(Type::Array.new(genv, elems, genv.gen_ary_type(unified_elem)))
      end

      def diff(prev_node)
        if prev_node.is_a?(ArrayNode) && @elems.size == prev_node.elems.size
          @elems.zip(prev_node.elems) do |elem, prev_elem|
            elem.diff(prev_elem)
            return unless elem.prev_node
          end
          @prev_node = prev_node
        end
      end
    end

    class HashNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @keys = []
        @vals = []
        #if raw_node.first_lineno == contents.first_lineno && raw_node.first_column == contents.first_column
        #  # Looks like there is no open brace
        #  @keywords = true
        #end
        raw_node.elements.each do |raw_elem|
          case raw_elem.type
          when :assoc_node
            @keys << AST.create_node(raw_elem.key, lenv)
            @vals << AST.create_node(raw_elem.value, lenv)
          else
            raise "unknown hash elem"
          end
        end
      end

      attr_reader :keys, :vals, :keywords

      def subnodes = { keys:, vals: }
      def attrs = { keywords: }

      def install0(genv)
        unified_key = Vertex.new("hash-keys-unified", self)
        unified_val = Vertex.new("hash-vals-unified", self)
        literal_pairs = {}
        @keys.zip(@vals) do |key, val|
          if key
            k = key.install(genv).new_vertex(genv, "hash-key", self)
            v = val.install(genv).new_vertex(genv, "hash-val", self)
            @changes.add_edge(genv, k, unified_key)
            @changes.add_edge(genv, v, unified_val)
            literal_pairs[key.lit] = v if key.is_a?(SymbolNode)
          else
            _h = val.install(genv)
            # TODO: if h is a hash, we need to connect its elements to the new hash
          end
        end
        Source.new(Type::Hash.new(genv, literal_pairs, genv.gen_hash_type(unified_key, unified_val)))
      end

      def diff(prev_node)
        if prev_node.is_a?(HashNode) && @keys.size == prev_node.keys.size
          @keys.zip(@vals, prev_node.keys, prev_node.vals) do |key, val, prev_key, prev_val|
            key.diff(prev_key)
            return unless key.prev_node
            val.diff(prev_val)
            return unless val.prev_node
          end
          @prev_node = prev_node
        end
      end
    end
  end
end
