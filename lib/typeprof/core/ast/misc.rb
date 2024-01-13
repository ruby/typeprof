module TypeProf::Core
  class AST
    class BLOCK < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        raw_stmts = raw_node.children
        @stmts = raw_stmts.map do |n|
          if n
            AST.create_node(n, lenv)
          else
            last = code_range.last
            NilNode.new(TypeProf::CodeRange.new(last, last), lenv)
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
        if prev_node.is_a?(BLOCK)
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

      def dump0(dumper)
        @stmts.map do |stmt|
          stmt.dump(dumper)
        end.join("\n")
      end
    end

    class BEGIN_ < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        #raise NotImplementedError if raw_node.children != [nil]
      end

      def install0(genv)
        # TODO
        Vertex.new("begin", self)
      end

      def uninstall0(genv)
        # TODO
      end

      def diff(prev_node)
        # TODO
        @prev_node = prev_node
      end

      def dump0(dumper)
        "begin; end"
      end
    end

    class DEFINED < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        raw_arg, = raw_node.children
        @arg = AST.create_node(raw_arg, lenv)
      end

      attr_reader :arg

      def subnodes = {} # no arg!

      def install0(genv)
        Source.new(genv.true_type, genv.false_type)
      end

      def dump0(dumper)
        "defined?(#{ @arg.dump(dumper) })"
      end
    end
  end
end