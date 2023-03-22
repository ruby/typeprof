module TypeProf::Core
  class AST
    class BranchNode < Node
      def initialize(raw_node, lenv)
        super
        raw_cond, raw_then, raw_else = raw_node.children
        @cond = AST.create_node(raw_cond, lenv)
        @then = AST.create_node(raw_then, lenv)
        @else = raw_else ? AST.create_node(raw_else, lenv) : nil
      end

      attr_reader :cond, :then, :else

      def subnodes = { cond:, then:, else: }

      def install0(genv)
        ret = Vertex.new("if", self)
        @cond.install(genv)
        @then.install(genv).add_edge(genv, ret)
        if @else
          else_val = @else.install(genv)
        else
          else_val = Source.new(Type::Instance.new([:NilClass]))
        end
        else_val.add_edge(genv, ret)
        ret
      end

      def dump0(dumper)
        s = "if #{ @cond.dump(dumper) }\n"
        s << @then.dump(dumper).gsub(/^/, "  ")
        if @else
          s << "\nelse\n"
          s << @else.dump(dumper).gsub(/^/, "  ")
        end
        s << "\nend"
      end
    end

    class IF < BranchNode
    end

    class UNLESS < BranchNode
    end

    class LoopNode < Node
      def initialize(raw_node, lenv)
        super
        raw_cond, raw_body, _do_while_flag = raw_node.children
        @cond = AST.create_node(raw_cond, lenv)
        @body = AST.create_node(raw_body, lenv)
      end

      attr_reader :cond, :body

      def subnodes = { cond:, body: }

      def install0(genv)
        @cond.install(genv)
        @body.install(genv)
        Source.new(Type::Instance.new([:NilClass]))
      end

      def dump0(dumper)
        s = "while #{ @cond.dump(dumper) }\n"
        s << @body.dump(dumper).gsub(/^/, "  ")
        s << "\nend"
      end
    end

    class WHILE < LoopNode
    end

    class UNTIL < LoopNode
    end

    class BREAK < Node
      def initialize(raw_node, lenv)
        super
        raw_arg, = raw_node.children
        @arg = raw_arg ? AST.create_node(raw_arg, lenv) : nil
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        _arg = @arg ? @arg.install(genv) : Source.new(Type::Instance.new([:NilClass]))
        # TODO: implement!
      end

      def dump0(dumper)
        "break #{ @cond.dump(dumper) }"
      end
    end

    class NEXT < Node
      def initialize(raw_node, lenv)
        super
        raw_arg, = raw_node.children
        @arg = raw_arg ? AST.create_node(raw_arg, lenv) : nil
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        arg = @arg ? @arg.install(genv) : Source.new(Type::Instance.new([:NilClass]))
        arg.add_edge(genv, @lenv.get_ret)
      end

      def dump0(dumper)
        "next #{ @cond.dump(dumper) }"
      end
    end

    class CASE < Node
      def initialize(raw_node, lenv)
        super
        raw_pivot, raw_when = raw_node.children
        @pivot = AST.create_node(raw_pivot, lenv)
        @clauses = []
        while raw_when && raw_when.type == :WHEN
          raw_vals, raw_clause, raw_when = raw_when.children
          @clauses << [
            AST.create_node(raw_vals, lenv),
            AST.create_node(raw_clause, lenv),
          ]
        end
        @else_clause = raw_when ? AST.create_node(raw_when, lenv) : nil
      end

      attr_reader :pivot, :clauses, :else_clause

      def subnodes
        h = { pivot:, else_clause: }
        clauses.each_with_index do |(vals, clause), i|
          h[i * 2] = vals
          h[i * 2 + 1] = clause
        end
        h
      end

      def install0(genv)
        ret = Vertex.new("case", self)
        @pivot.install(genv)
        @clauses.each do |vals, clause|
          vals.install(genv)
          clause.install(genv).add_edge(genv, ret)
        end
        if @else_clause
          @else_clause.install(genv).add_edge(genv, ret)
        else
          Source.new(Type::Instance.new([:NilClass])).add_edge(genv, ret)
        end
        ret
      end

      def diff(prev_node)
        if prev_node.is_a?(CASE) && @clauses.size == prev_node.clauses.size
          @pivot.diff(prev_node.pivot)
          return unless @pivot.prev_node

          @clauses.zip(prev_node.clauses) do |(vals, clause), (prev_vals, prev_clause)|
            vals.diff(prev_vals)
            return unless vals.prev_node
            clause.diff(prev_clause)
            return unless clause.prev_node
          end

          if @else_clause
            @else_clause.diff(prev_node.else_clause)
            return unless @else_clause.prev_node
          else
            return if @else_clause != prev_node.else_clause
          end

          @prev_node = prev_node
        end
      end

      def dump0(dumper)
        s = "case #{ @pivot.dump(dumper) }"
        @clauses.each do |vals, clause|
          s << "\nwhen #{ vals.dump(dumper) }\n"
          s << clause.dump(dumper).gsub(/^/, "  ")
        end
        if @else_clause
          s << "\nelse\n"
          s << @else_clause.dump(dumper).gsub(/^/, "  ")
        end
        s << "\nend"
      end
    end

    class AND < Node
      def initialize(raw_node, lenv)
        super
        raw_e1, raw_e2 = raw_node.children
        @e1 = AST.create_node(raw_e1, lenv)
        @e2 = AST.create_node(raw_e2, lenv)
      end

      attr_reader :e1, :e2

      def subnodes = { e1:, e2: }

      def install0(genv)
        ret = Vertex.new("and", self)
        @e1.install(genv).add_edge(genv, ret)
        @e2.install(genv).add_edge(genv, ret)
        ret
      end

      def dump0(dumper)
        "(#{ @e1.dump(dumper) } && #{ @e2.dump(dumper) })"
      end
    end

    class RETURN < Node
      def initialize(raw_node, lenv)
        super
        raw_arg, = raw_node.children
        @arg = raw_arg ? AST.create_node(raw_arg, lenv) : nil
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        ret = @arg ? @arg.install(genv) : Source.new(Type::Instance.new([:NilClass]))
        lenv = @lenv
        lenv = lenv.outer while lenv.outer
        ret.add_edge(genv, lenv.get_ret)
        Vertex.new("dummy", self)
      end

      def dump0(dumper)
        "return#{ @arg ? " " + @arg.dump(dumper) : "" }"
      end
    end

    class RESCUE < Node
      def initialize(raw_node, lenv)
        super
        raw_body, _raw_rescue = raw_node.children
        @body = AST.create_node(raw_body, lenv)
        # TODO: raw_rescue
      end

      attr_reader :body

      def subnodes = { body: }

      def install0(genv)
        @body.install(genv)
      end

      def diff(prev_node)
        raise NotImplementedError
      end
    end
  end
end