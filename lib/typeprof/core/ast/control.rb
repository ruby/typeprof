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
        else_clause = raw_node.is_a?(Prism::IfNode) ? raw_node.subsequent : raw_node.else_clause
        if else_clause
          else_clause = else_clause.statements if else_clause.type == :else_node
          @else = else_clause ? AST.create_node(else_clause, lenv) : nil
        else
          @else = nil
        end
      end

      attr_reader :cond, :then, :else

      def subnodes = { cond:, then:, else: }

      def install0(genv)
        ret = Vertex.new(self)

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
          nvtx_then = vtx.new_vertex(genv, self)
          nvtx_else = vtx.new_vertex(genv, self)
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
        @changes.add_edge(genv, then_val, ret)

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
        @changes.add_edge(genv, else_val, ret)

        modified_vtxs.each do |var, (nvtx_then, nvtx_else)|
          nvtx_then = BotFilter.new(genv, self, nvtx_then, then_val).next_vtx
          nvtx_else = BotFilter.new(genv, self, nvtx_else, else_val).next_vtx
          nvtx_join = nvtx_then.new_vertex(genv, self)
          @changes.add_edge(genv, nvtx_else, nvtx_join)
          @lenv.set_var(var, nvtx_join)
        end

        ret
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
        @body = raw_node.statements ? AST.create_node(raw_node.statements, lenv) : DummyNilNode.new(code_range, lenv)
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
          nvtx = vtx.new_vertex(genv, self)
          old_vtxs[var] = nvtx
          @lenv.set_var(var, nvtx)
        end

        @cond.install(genv)
        if @cond.is_a?(LocalVariableReadNode)
          nvtx_then = NilFilter.new(genv, self, old_vtxs[@cond.var], self.is_a?(UntilNode)).next_vtx
          @lenv.set_var(@cond.var, nvtx_then)
        end

        if @lenv.exist_var?(:"*expected_block_ret")
          expected_block_ret = @lenv.locals[:"*expected_block_ret"]
          @lenv.set_var(:"*expected_block_ret", nil)
        end

        @body.install(genv)

        if expected_block_ret
          @lenv.set_var(:"*expected_block_ret", expected_block_ret)
        end

        vars.each do |var|
          @changes.add_edge(genv, @lenv.get_var(var), old_vtxs[var])
          @lenv.set_var(var, old_vtxs[var])
        end
        if @cond.is_a?(LocalVariableReadNode)
          nvtx_then = NilFilter.new(genv, self, old_vtxs[@cond.var], !self.is_a?(UntilNode)).next_vtx
          @lenv.set_var(@cond.var, nvtx_then)
        end

        Source.new(genv.nil_type)
      end
    end

    class WhileNode < LoopNode
    end

    class UntilNode < LoopNode
    end

    class BreakNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @arg = AST.parse_return_arguments(raw_node, lenv, code_range)
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        arg = @arg.install(genv)
        @changes.add_edge(genv, arg, @lenv.get_break_vtx)
        Source.new()
      end
    end

    def self.parse_return_arguments(raw_node, lenv, code_range)
      if raw_node.arguments
        elems = raw_node.arguments.arguments
        if elems.one?
          AST.create_node(elems.first, lenv)
        else
          ArrayNode.new(raw_node.arguments, lenv, elems)
        end
      else
        DummyNilNode.new(code_range, lenv)
      end
    end

    class NextNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @arg = AST.parse_return_arguments(raw_node, lenv, code_range)
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        @arg.install(genv)
        if @lenv.exist_var?(:"*expected_block_ret")
          @lenv.add_next_box(@changes.add_escape_box(genv, @arg.ret, @lenv.get_var(:"*expected_block_ret")))
        end
        Source.new(Type::Bot.new(genv))
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
    end

    class CaseNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @pivot = raw_node.predicate ? AST.create_node(raw_node.predicate, lenv) : nil
        @whens = []
        @clauses = []
        raw_node.conditions.each do |raw_cond|
          @whens << AST.create_node(raw_cond.conditions.first, lenv) # XXX: multiple conditions
          @clauses << (raw_cond.statements ? AST.create_node(raw_cond.statements, lenv) : DummyNilNode.new(code_range, lenv)) # TODO: code_range for NilNode
        end
        @else_clause = raw_node.else_clause && raw_node.else_clause.statements ? AST.create_node(raw_node.else_clause.statements, lenv) : DummyNilNode.new(code_range, lenv) # TODO: code_range for NilNode
      end

      attr_reader :pivot, :whens, :clauses, :else_clause

      def subnodes = { pivot:, whens:, clauses:, else_clause: }

      def install0(genv)
        ret = Vertex.new(self)
        @pivot&.install(genv)
        @whens.zip(@clauses) do |vals, clause|
          vals.install(genv)
          @changes.add_edge(genv, clause.install(genv), ret)
        end
        @changes.add_edge(genv, @else_clause.install(genv), ret)
        ret
      end
    end

    class CaseMatchNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @pivot = AST.create_node(raw_node.predicate, lenv)
        @patterns = []
        @clauses = []
        raw_node.conditions.each do |raw_cond|
          raise if raw_cond.type != :in_node
          @patterns << AST.create_pattern_node(raw_cond.pattern, lenv)
          @clauses << (raw_cond.statements ? AST.create_node(raw_cond.statements, lenv) : DummyNilNode.new(code_range, lenv)) # TODO: code_range for NilNode
        end
        @else_clause = raw_node.else_clause && raw_node.else_clause.statements ? AST.create_node(raw_node.else_clause.statements, lenv) : nil
      end

      attr_reader :pivot, :patterns, :clauses, :else_clause

      def subnodes = { pivot:, patterns:, clauses:, else_clause: }

      def install0(genv)
        ret = Vertex.new(self)
        @pivot&.install(genv)
        @patterns.zip(@clauses) do |pattern, clause|
          pattern.install(genv)
          @changes.add_edge(genv, clause.install(genv), ret)
        end
        @changes.add_edge(genv, @else_clause.install(genv), ret) if @else_clause
        ret
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
        ret = Vertex.new(self)
        @changes.add_edge(genv, @e1.install(genv), ret)
        @changes.add_edge(genv, @e2.install(genv), ret)
        ret
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
        ret = Vertex.new(self)
        v1 = @e1.install(genv)
        v1 = NilFilter.new(genv, self, v1, false).next_vtx
        @changes.add_edge(genv, v1, ret)
        @changes.add_edge(genv, @e2.install(genv), ret)
        ret
      end
    end

    class ReturnNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @arg = AST.parse_return_arguments(raw_node, lenv, code_range)
      end

      attr_reader :arg

      def subnodes = { arg: }

      def install0(genv)
        @arg.install(genv)
        e_ret = @lenv.locals[:"*expected_method_ret"]
        @lenv.add_return_box(@changes.add_escape_box(genv, @arg.ret, e_ret)) if e_ret
        Source.new(Type::Bot.new(genv))
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
          raw_res = raw_res.subsequent
        end
        @else_clause = raw_node.else_clause&.statements ? AST.create_node(raw_node.else_clause.statements, lenv) : DummyNilNode.new(code_range, lenv)
        @ensure_clause = raw_node.ensure_clause&.statements ? AST.create_node(raw_node.ensure_clause.statements, lenv) : DummyNilNode.new(code_range, lenv)
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
        ret = Vertex.new(self)
        @changes.add_edge(genv, @body.install(genv), ret)
        @rescue_conds.each {|cond| cond.install(genv) }
        @rescue_clauses.each {|clause| @changes.add_edge(genv, clause.install(genv), ret) }
        @changes.add_edge(genv, @else_clause.install(genv), ret) if @else_clause
        @ensure_clause.install(genv) if @ensure_clause
        ret
      end
    end

    class RetryNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
      end

      def install0(genv)
        Source.new(Type::Bot.new(genv))
      end
    end

    class RescueModifierNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @expression = AST.create_node(raw_node.expression, lenv)
        @rescue_expression = AST.create_node(raw_node.rescue_expression, lenv)
      end

      attr_reader :expression, :rescue_expression

      def subnodes = { expression:, rescue_expression: }

      def install0(genv)
        ret = Vertex.new(self)
        @changes.add_edge(genv, @expression.install(genv), ret)
        @changes.add_edge(genv, @rescue_expression.install(genv), ret)
        ret
      end
    end
  end
end
