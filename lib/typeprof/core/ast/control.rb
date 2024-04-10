module TypeProf::Core
  class AST
    def self.is_a_class(node)
      if node.is_a?(CallNode)
        recv = node.recv
        if recv.is_a?(LocalVariableReadNode)
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
        super(raw_node, lenv)
        @cond = AST.create_node(raw_node.predicate, lenv)
        @then = raw_node.statements ? AST.create_node(raw_node.statements, lenv) : nil
        @else = raw_node.consequent && raw_node.consequent.statements ? AST.create_node(raw_node.consequent.statements, lenv) : nil
      end

      attr_reader :cond, :then, :else

      def subnodes = { cond:, then:, else: }

      def install0(genv)
        ret = Vertex.new("if", self)

        @cond.install(genv)

        vars = []
        vars << @cond.var if @cond.is_a?(LocalVariableReadNode)
        var, filter_class = AST.is_a_class(@cond)
        vars << var if var
        @then.modified_vars(@lenv.locals.keys, vars) if @then
        @else.modified_vars(@lenv.locals.keys, vars) if @else
        modified_vtxs = {}
        vars.uniq.each do |var|
          vtx = @lenv.get_var(var)
          nvtx_then = vtx.new_vertex(genv, "#{ vtx.is_a?(Vertex) ? vtx.show_name : "???" }'", self)
          nvtx_else = vtx.new_vertex(genv, "#{ vtx.is_a?(Vertex) ? vtx.show_name : "???" }'", self)
          modified_vtxs[var] = [nvtx_then, nvtx_else]
        end
        if @cond.is_a?(LocalVariableReadNode)
          nvtx_then, nvtx_else = modified_vtxs[@cond.var]
          nvtx_then = NilFilter.new(genv, self, nvtx_then, !self.is_a?(IfNode)).next_vtx
          nvtx_else = NilFilter.new(genv, self, nvtx_else, self.is_a?(IfNode)).next_vtx
          modified_vtxs[@cond.var] = [nvtx_then, nvtx_else]
        end
        if filter_class
          nvtx_then, nvtx_else = modified_vtxs[var]
          nvtx_then = IsAFilter.new(genv, self, nvtx_then, !self.is_a?(IfNode), filter_class).next_vtx
          nvtx_else = IsAFilter.new(genv, self, nvtx_else, self.is_a?(IfNode), filter_class).next_vtx
          modified_vtxs[var] = [nvtx_then, nvtx_else]
        end

        if @then
          modified_vtxs.each do |var, (nvtx_then, _)|
            @lenv.set_var(var, nvtx_then)
          end
          if @cond.is_a?(InstanceVariableReadNode)
            @lenv.push_read_filter(@cond.var, :non_nil)
          end
          then_val = @then.install(genv)
          if @cond.is_a?(InstanceVariableReadNode)
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
        s = "#{ self.is_a?(IfNode) ? "if" : "unless" } #{ @cond.dump(dumper) }\n"
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

    class IfNode < BranchNode
    end

    class UnlessNode < BranchNode
    end

    class LoopNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @cond = AST.create_node(raw_node.predicate, lenv)
        @body = AST.create_node(raw_node.statements, lenv)
      end

      attr_reader :cond, :body

      def subnodes = { cond:, body: }

      def install0(genv)
        vars = []
        vars << @cond.var if @cond.is_a?(LocalVariableReadNode)
        @cond.modified_vars(@lenv.locals.keys, vars)
        @body.modified_vars(@lenv.locals.keys, vars)
        vars.uniq!
        old_vtxs = {}
        vars.each do |var|
          vtx = @lenv.get_var(var)
          nvtx = vtx.new_vertex(genv, "#{ vtx.is_a?(Vertex) ? vtx.show_name : "???" }'", self)
          old_vtxs[var] = nvtx
          @lenv.set_var(var, nvtx)
        end

        @cond.install(genv)
        if @cond.is_a?(LocalVariableReadNode)
          nvtx_then = NilFilter.new(genv, self, old_vtxs[@cond.var], self.is_a?(UntilNode)).next_vtx
          @lenv.set_var(@cond.var, nvtx_then)
        end
        @body.install(genv)

        vars.each do |var|
          @lenv.get_var(var).add_edge(genv, old_vtxs[var])
          @lenv.set_var(var, old_vtxs[var])
        end
        if @cond.is_a?(LocalVariableReadNode)
          nvtx_then = NilFilter.new(genv, self, old_vtxs[@cond.var], !self.is_a?(UntilNode)).next_vtx
          @lenv.set_var(@cond.var, nvtx_then)
        end

        Source.new(genv.nil_type)
      end

      def dump0(dumper)
        s = "while #{ @cond.dump(dumper) }\n"
        s << @body.dump(dumper).gsub(/^/, "  ")
        s << "\nend"
      end
    end

    class WhileNode < LoopNode
    end

    class UntilNode < LoopNode
    end

    class BreakNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @arg = raw_node.arguments ? AST.create_node(raw_node.arguments.arguments.first, lenv) : nil
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

    class NextNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        # TODO: next 1, 2
        @arg = raw_node.arguments ? AST.create_node(raw_node.arguments.arguments.first, lenv) : DummyNilNode.new(code_range, lenv)
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        @arg.install(genv)
        Source.new(Type::Bot.new(genv))
      end

      def dump0(dumper)
        "next #{ @cond.dump(dumper) }"
      end
    end

    class RedoNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
      end

      def install0(genv)
        # TODO: This should return a bot type
        Source.new()
      end

      def dump0(dumper)
        "redo"
      end
    end

    class CaseNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @pivot = AST.create_node(raw_node.predicate, lenv)
        @whens = []
        @clauses = []
        raw_node.conditions.each do |raw_cond|
          @whens << AST.create_node(raw_cond.conditions.first, lenv) # XXX: multiple conditions
          @clauses << (raw_cond.statements ? AST.create_node(raw_cond.statements, lenv) : DummyNilNode.new(code_range, lenv)) # TODO: code_range for NilNode
        end
        @else_clause = raw_node.consequent && raw_node.consequent.statements ? AST.create_node(raw_node.consequent.statements, lenv) : DummyNilNode.new(code_range, lenv) # TODO: code_range for NilNode
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
        if prev_node.is_a?(CaseNode) && @clauses.size == prev_node.clauses.size
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

    class AndNode < Node
      def initialize(raw_node, e1 = nil, raw_e2 = nil, lenv)
        super(raw_node, lenv)
        @e1 = e1 || AST.create_node(raw_node.left, lenv)
        @e2 = AST.create_node(raw_e2 || raw_node.right, lenv)
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

    class OrNode < Node
      def initialize(raw_node, e1 = nil, raw_e2 = nil, lenv)
        super(raw_node, lenv)
        @e1 = e1 || AST.create_node(raw_node.left, lenv)
        @e2 = AST.create_node(raw_e2 || raw_node.right, lenv)
      end

      attr_reader :e1, :e2

      def subnodes = { e1:, e2: }

      def install0(genv)
        ret = Vertex.new("or", self)
        v1 = @e1.install(genv)
        v1 = NilFilter.new(genv, self, v1, false).next_vtx
        v1.add_edge(genv, ret)
        @e2.install(genv).add_edge(genv, ret)
        ret
      end

      def dump0(dumper)
        "(#{ @e1.dump(dumper) } && #{ @e2.dump(dumper) })"
      end
    end

    class ReturnNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        # TODO: return x, y
        @arg = raw_node.arguments ? AST.create_node(raw_node.arguments.arguments.first, lenv) : DummyNilNode.new(code_range, lenv)
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        @arg.install(genv)
        Source.new(Type::Bot.new(genv))
      end

      def dump0(dumper)
        "return#{ " " + @arg.dump(dumper) }"
      end
    end

    class BeginNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @body = raw_node.statements ? AST.create_node(raw_node.statements, lenv) : DummyNilNode.new(code_range, lenv)
        @rescue_conds = []
        @rescue_clauses = []
        raw_res = raw_node.rescue_clause
        while raw_res
          raw_res.exceptions.each do |raw_cond|
            @rescue_conds << AST.create_node(raw_cond, lenv)
          end
          if raw_res.statements
            @rescue_clauses << AST.create_node(raw_res.statements, lenv)
          end
          raw_res = raw_res.consequent
        end
        @else_clause = raw_node.else_clause ? AST.create_node(raw_node.else_clause.statements, lenv) : DummyNilNode.new(code_range, lenv)
        @ensure_clause = raw_node.ensure_clause ? AST.create_node(raw_node.ensure_clause.statements, lenv) : DummyNilNode.new(code_range, lenv)
      end

      attr_reader :body, :rescue_conds, :rescue_clauses, :else_clause, :ensure_clause

      def subnodes = { body:, rescue_conds:, rescue_clauses:, else_clause:, ensure_clause: }

      def define0(genv)
        @body.define(genv)
        @rescue_conds.each {|cond| cond.define(genv) }
        @rescue_clauses.each {|clause| clause.define(genv) }
        @else_clause.define(genv) if @else_clause
        @ensure_clause.define(genv) if @ensure_clause
      end

      def undefine0(genv)
        @body.undefine(genv)
        @rescue_conds.each {|cond| cond.undefine(genv) }
        @rescue_clauses.each {|clause| clause.undefine(genv) }
        @else_clause.undefine(genv) if @else_clause
        @ensure_clause.undefine(genv) if @ensure_clause
      end

      def install0(genv)
        ret = Vertex.new("rescue-ret", self)
        @body.install(genv).add_edge(genv, ret)
        @rescue_conds.each {|cond| cond.install(genv) }
        @rescue_clauses.each {|clause| clause.install(genv).add_edge(genv, ret) }
        @else_clause.install(genv).add_edge(genv, ret) if @else_clause
        @ensure_clause.install(genv) if @ensure_clause
        ret
      end

      def diff(prev_node)
        if prev_node.is_a?(BeginNode)
          @body.diff(prev_node.body)
          return unless @body.prev_node

          if @rescue_conds.size == prev_node.rescue_conds.size && @rescue_clauses.size == prev_node.rescue_clauses.size
            @rescue_conds.zip(prev_node.rescue_conds) do |cond, prev_cond|
              cond.diff(prev_cond)
              return unless cond.prev_node
            end

            @rescue_clauses.zip(prev_node.rescue_clauses) do |clause, prev_clause|
              clause.diff(prev_clause)
              return unless clause.prev_node
            end
          end

          if @else_clause && prev_node.else_clause
            @else_clause.diff(prev_node.else_clause)
            return unless @else_clause.prev_node
          else
            return if @else_clause != prev_node.else_clause
          end

          if @ensure_clause && prev_node.ensure_clause
            @ensure_clause.diff(prev_node.ensure_clause)
            return unless @ensure_clause.prev_node
          else
            return if @ensure_clause != prev_node.ensure_clause
          end
        end
      end
    end
  end
end
