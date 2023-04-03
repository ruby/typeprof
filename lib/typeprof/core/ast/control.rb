module TypeProf::Core
  class AST
    def self.is_a_class(node)
      if node.is_a?(CALL)
        recv = node.recv
        if recv.is_a?(LVAR)
          if node.positional_args && node.positional_args.size == 1 && node.positional_args[0].static_ret
            # TODO: need static resolusion of a constant
            return [recv.var, node.positional_args[0].static_ret]
          end
        end
      end
      return nil
    end

    class BranchNode < Node
      def initialize(raw_node, lenv)
        super
        raw_cond, raw_then, raw_else = raw_node.children
        @cond = AST.create_node(raw_cond, lenv)
        @then = raw_then ? AST.create_node(raw_then, lenv) : nil
        @else = raw_else ? AST.create_node(raw_else, lenv) : nil
      end

      attr_reader :cond, :then, :else

      def subnodes = { cond:, then:, else: }

      def install0(genv)
        ret = Vertex.new("if", self)

        @cond.install(genv)

        vars = Set[]
        vars << @cond.var if @cond.is_a?(LVAR)
        var, filtered_class = AST.is_a_class(@cond)
        vars << var if var
        @then.modified_vars(@lenv.locals.keys, vars) if @then
        @else.modified_vars(@lenv.locals.keys, vars) if @else
        modified_vtxs = {}
        vars.each do |var|
          vtx = @lenv.get_var(var)
          nvtx_then = vtx.new_vertex(genv, "#{ vtx.is_a?(Vertex) ? vtx.show_name : "???" }'", self)
          nvtx_else = vtx.new_vertex(genv, "#{ vtx.is_a?(Vertex) ? vtx.show_name : "???" }'", self)
          modified_vtxs[var] = [nvtx_then, nvtx_else]
        end
        if @cond.is_a?(LVAR)
          nvtx_then, nvtx_else = modified_vtxs[@cond.var]
          nvtx_then = NilFilter.new(genv, self, nvtx_then, !self.is_a?(IF)).next_vtx
          nvtx_else = NilFilter.new(genv, self, nvtx_else, self.is_a?(IF)).next_vtx
          modified_vtxs[@cond.var] = nvtx_then, nvtx_else
        end
        if filtered_class
          nvtx_then, nvtx_else = modified_vtxs[var]
          nvtx_then = IsAFilter.new(genv, self, nvtx_then, !self.is_a?(IF), filtered_class).next_vtx
          nvtx_else = IsAFilter.new(genv, self, nvtx_else, self.is_a?(IF), filtered_class).next_vtx
          modified_vtxs[var] = nvtx_then, nvtx_else
        end

        if @then
          modified_vtxs.each do |var, (nvtx_then, _)|
            @lenv.set_var(var, nvtx_then)
          end
          if @cond.is_a?(IVAR)
            @lenv.push_read_filter(@cond.var, :non_nil)
          end
          then_val = @then.install(genv)
          if @cond.is_a?(IVAR)
            @lenv.pop_read_filter(@cond.var)
          end
          modified_vtxs.each do |var, ary|
            ary[0] = @lenv.get_var(var)
          end
        else
          then_val = Source.new(genv.nil_type)
        end
        then_val.add_edge(genv, ret)

        if @else
          modified_vtxs.each do |var, (_, nvtx_else)|
            @lenv.set_var(var, nvtx_else)
          end
          else_val = @else.install(genv)
          modified_vtxs.each do |var, ary|
            ary[1] = @lenv.get_var(var)
          end
        else
          else_val = Source.new(genv.nil_type)
        end
        else_val.add_edge(genv, ret)

        modified_vtxs.each do |var, (nvtx_then, nvtx_else)|
          nvtx_then = BotFilter.new(genv, self, nvtx_then, then_val).next_vtx
          nvtx_else = BotFilter.new(genv, self, nvtx_else, else_val).next_vtx
          nvtx_join = nvtx_then.new_vertex(genv, "xxx", self)
          nvtx_else.add_edge(genv, nvtx_join)
          @lenv.set_var(var, nvtx_join)
        end

        ret
      end

      def dump0(dumper)
        s = "#{ self.is_a?(IF) ? "if" : "unless" } #{ @cond.dump(dumper) }\n"
        if @then
          s << @then.dump(dumper).gsub(/^/, "  ")
        end
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
        vars = Set[]
        @cond.modified_vars(@lenv.locals.keys, vars)
        @body.modified_vars(@lenv.locals.keys, vars)
        old_vtxs = {}
        vars.each do |var|
          vtx = @lenv.get_var(var)
          nvtx = vtx.new_vertex(genv, "#{ vtx.is_a?(Vertex) ? vtx.show_name : "???" }'", self)
          old_vtxs[var] = nvtx
          @lenv.set_var(var, nvtx)
        end

        @cond.install(genv)
        @body.install(genv)

        vars.each do |var|
          @lenv.get_var(var).add_edge(genv, old_vtxs[var])
          @lenv.set_var(var, old_vtxs[var])
        end

        Source.new(genv.nil_type)
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
        _arg = @arg ? @arg.install(genv) : Source.new(genv.nil_type)
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
        arg = @arg ? @arg.install(genv) : Source.new(genv.nil_type)
        arg.add_edge(genv, @lenv.get_var(:"*block_ret"))
        Source.new(Type::Bot.new)
      end

      def dump0(dumper)
        "next #{ @cond.dump(dumper) }"
      end
    end

    class REDO < Node
      def initialize(raw_node, lenv)
        super
      end

      def install0(genv)
        # TODO: This should return a bot type
        Source.new()
      end

      def dump0(dumper)
        "redo"
      end
    end

    class CASE < Node
      def initialize(raw_node, lenv)
        super
        raw_pivot, raw_when = raw_node.children
        @pivot = AST.create_node(raw_pivot, lenv)
        @whens = []
        @clauses = []
        while raw_when && raw_when.type == :WHEN
          raw_vals, raw_clause, raw_when = raw_when.children
          @whens << AST.create_node(raw_vals, lenv)
          @clauses << (raw_clause ? AST.create_node(raw_clause, lenv) : NilNode.new(code_range, lenv)) # TODO: code_range for NilNode
        end
        @else_clause = raw_when ? AST.create_node(raw_when, lenv) : NilNode.new(code_range, lenv) # TODO: code_range for NilNode
      end

      attr_reader :pivot, :whens, :clauses, :else_clause

      def subnodes = { pivot:, whens:, clauses:, else_clause: }

      def install0(genv)
        ret = Vertex.new("case", self)
        @pivot.install(genv)
        @whens.zip(@clauses) do |vals, clause|
          vals.install(genv)
          clause.install(genv).add_edge(genv, ret)
        end
        @else_clause.install(genv).add_edge(genv, ret)
        ret
      end

      def diff(prev_node)
        if prev_node.is_a?(CASE) && @clauses.size == prev_node.clauses.size
          @pivot.diff(prev_node.pivot)
          return unless @pivot.prev_node

          @whens.zip(@clauses, prev_node.whens, prev_node.clauses) do |vals, clause, prev_vals, prev_clause|
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
        @whens.zip(@clauses) do |vals, clause|
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

    class OR < Node
      def initialize(raw_node, lenv)
        super
        raw_e1, raw_e2 = raw_node.children
        @e1 = AST.create_node(raw_e1, lenv)
        @e2 = AST.create_node(raw_e2, lenv)
      end

      attr_reader :e1, :e2

      def subnodes = { e1:, e2: }

      def install0(genv)
        ret = Vertex.new("or", self)
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
        ret = @arg ? @arg.install(genv) : Source.new(genv.nil_type)
        ret.add_edge(genv, @lenv.get_var(:"*ret"))
        Source.new(Type::Bot.new)
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
    end
  end
end