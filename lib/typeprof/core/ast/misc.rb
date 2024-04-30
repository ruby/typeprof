module TypeProf::Core
  class AST
    class StatementsNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @stmts = raw_node.body.map do |n|
          if n
            AST.create_node(n, lenv)
          else
            last = code_range.last
            DummyNilNode.new(TypeProf::CodeRange.new(last, last), lenv)
          end
        end
      end

      attr_reader :stmts

      def subnodes = { stmts: }

      def install0(genv)
        ret = nil
        @stmts.each do |stmt|
          ret = stmt ? stmt.install(genv) : nil
        end
        ret || Source.new(genv.nil_type)
      end

      def diff(prev_node)
        if prev_node.is_a?(StatementsNode)
          i = 0
          while i < @stmts.size
            @stmts[i].diff(prev_node.stmts[i])
            if !@stmts[i].prev_node
              j1 = @stmts.size - 1
              j2 = prev_node.stmts.size - 1
              while j1 >= i && j2 >= i
                @stmts[j1].diff(prev_node.stmts[j2])
                if !@stmts[j1].prev_node
                  return
                end
                j1 -= 1
                j2 -= 1
              end
              return
            end
            i += 1
          end
          if i == prev_node.stmts.size
            @prev_node = prev_node
          end
        end
      end
    end

    class MultiWriteNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @rhs = AST.create_node(raw_node.value, lenv)
        @lhss = []
        raw_node.lefts.each do |raw_lhs|
          lhs = AST.create_target_node(raw_lhs, lenv)
          @lhss << lhs
        end
      end

      attr_reader :rhs, :lhss

      def subnodes = { rhs:, lhss: }

      def install0(genv)
        @lhss.each {|lhs| lhs.install(genv) }
        rhs = @rhs.install(genv)
        site = @changes.add_masgn_site(genv, self, rhs, @lhss.map {|lhs| lhs.rhs.ret || raise(lhs.rhs.inspect) })
        site.ret
      end

      def retrieve_at(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
      end
    end

    class DefinedNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @arg = AST.create_node(raw_node.value, lenv)
      end

      attr_reader :arg

      def subnodes = {} # no arg!

      def install0(genv)
        Source.new(genv.true_type, genv.false_type)
      end
    end
  end
end
