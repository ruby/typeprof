module TypeProf::Core
  class AST
    class SELF < Node
      def install0(genv)
        @lenv.get_var(:"*self")
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
        when NilClass then Source.new(Type.nil)
        when TrueClass then Source.new(Type.true)
        when FalseClass then Source.new(Type.false)
        when Integer then Source.new(Type.int)
        when Float then Source.new(Type.float)
        when Regexp then Source.new(Type::Instance.new([:Regexp]))
        when Symbol
          Source.new(Type::Symbol.new(@lit))
        else
          raise "not supported yet: #{ @lit.inspect }"
        end
      end

      def diff(prev_node)
        # Need to compare their classes to distinguish between 1 and 1.0 (or use equal?)
        if prev_node.is_a?(LIT) && @lit.class == prev_node.lit.class && @lit == prev_node.lit
          @prev_node = prev_node
        end
      end

      def dump0(dumper)
        @lit.inspect
      end
    end

    class STR < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        str, raw_evstr, raw_list = raw_node.children
        raise if raw_evstr && raw_evstr.type != :EVSTR
        @strs = [str]
        @interpolations = []
        if raw_evstr
          @interpolations << AST.create_node(raw_evstr.children.first, lenv)
          if raw_list
            raw_list.children.compact.each do |node|
              case node.type
              when :EVSTR
                @interpolations << AST.create_node(node.children.first, lenv)
              when :STR
                @strs << node.children.first
              else
                raise "#{ node.type } in DSTR??"
              end
            end
          end
        end
      end

      attr_reader :interpolations, :strs

      def subnodes
        h = {}
        @interpolations.each_with_index do |subnode, i|
          h[i] = subnode
        end
        h
      end
      def attrs = { strs: }

      def install0(genv)
        @interpolations.each do |subnode|
          subnode.install(genv)
        end
        Source.new(Type::Instance.new([:String]))
      end

      def diff(prev_node)
        if prev_node.is_a?(STR) && @strs == prev_node.strs && @interpolations.size == prev_node.interpolations.size
          @interpolations.zip(prev_node.interpolations) do |n, prev_n|
            n.diff(prev_n)
            return unless n.prev_node
          end
          @prev_node = prev_node
        end
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
        elems = @elems.map {|e| e.install(genv).new_vertex(genv, "ary-elem", self) }
        unified_elem = Vertex.new("ary-elems-unified", self)
        elems.each {|vtx| vtx.add_edge(genv, unified_elem) }
        Source.new(Type::Array.new(elems, unified_elem, Type.ary))
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

    class HASH < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        cs = raw_node.children
        raise "HASH???" if cs.size != 1
        contents = cs.first
        @elems = {}
        if contents
          case contents.type
          when :LIST
            cs.first.children.compact.each_slice(2) do |key, val|
              @elems[AST.create_node(key, lenv)] = AST.create_node(val, lenv)
            end
          else
             raise "not supported hash: #{ contents.type }"
          end
        end
      end

      attr_reader :elems

      def subnodes
        h = {}
        @elems.each_with_index do |(key, val), i|
          h[i * 2] = key
          h[i * 2 + 1] = val
        end
        h
      end

      def install0(genv)
        unified_key = Vertex.new("hash-keys-unified", self)
        unified_val = Vertex.new("hash-vals-unified", self)
        literal_pairs = {}
        @elems.each do |key, val|
          k = key.install(genv).new_vertex(genv, "hash-key", self)
          v = val.install(genv).new_vertex(genv, "hash-val", self)
          k.add_edge(genv, unified_key)
          v.add_edge(genv, unified_val)
          literal_pairs[key.lit] = v if key.is_a?(LIT) && key.lit.is_a?(Symbol)
        end
        Source.new(Type::Hash.new(literal_pairs, unified_key, unified_val, Type.hsh))
      end

      def diff(prev_node)
        if prev_node.is_a?(HASH) && @elems.size == prev_node.elems.size
          @elems.zip(prev_node.elems) do |(key, val), (prev_key, prev_val)|
            key.diff(prev_key)
            return unless key.prev_node
            val.diff(prev_val)
            return unless val.prev_node
          end
          @prev_node = prev_node
        end
      end

      def dump0(dumper)
        "{ #{ @elems.map {|key, val| key.dump(dumper) + " => " + val.dump(dumper) }.join(", ") } }"
      end
    end

    class DOT2 < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        raw_begin, raw_end = raw_node.children
        @begin = AST.create_node(raw_begin, lenv)
        @end = AST.create_node(raw_end, lenv)
      end

      attr_reader :begin, :end

      def subnodes = { begin:, end: }

      def install0(genv)
        elem = Vertex.new("range-elem", self)
        @begin.install(genv).add_edge(genv, elem)
        @end.install(genv).add_edge(genv, elem)
        Source.new(Type::Array.new(nil, elem, Type.range))
      end

      def dump0(dumper)
        "(#{ @begin.dump(dumper) } .. #{ @end.dump(dumper) })"
      end
    end
  end
end