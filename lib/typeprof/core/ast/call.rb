module TypeProf::Core
  class AST
    class CallBaseNode < Node
      def initialize(raw_node, recv, mid, mid_code_range, raw_args, last_arg, raw_block, lenv, forwarding_arguments: false)
        super(raw_node, lenv)

        @recv = recv
        @mid = mid
        @mid_code_range = mid_code_range

        # args
        @positional_args = []
        @splat_flags = []
        @keyword_args = nil

        @block_pass = nil
        @block_tbl = nil
        @block_f_args = nil
        @block_opt_positional_defaults = nil
        @block_body = nil
        @safe_navigation = raw_node.respond_to?(:safe_navigation?) && raw_node.safe_navigation?
        @anonymous_block_forwarding = false
        @forwarding_arguments = forwarding_arguments

        if raw_args
          args = []
          @splat_flags = []
          raw_args.arguments.each do |raw_arg|
            case raw_arg
            when Prism::SplatNode
              args << raw_arg.expression
              @splat_flags << true
            when Prism::ForwardingArgumentsNode
              @forwarding_arguments = true
            else
              args << raw_arg
              @splat_flags << false
            end
          end
          @positional_args = args.map {|arg| arg ? AST.create_node(arg, lenv) : DummyNilNode.new(code_range, lenv) }

          kw = @positional_args.last
          if kw.is_a?(TypeProf::Core::AST::HashNode) && kw.keywords
            @keyword_args = @positional_args.pop
          end
        end

        @positional_args << last_arg if last_arg

        if raw_block
          if raw_block.type == :block_argument_node
            if raw_block.expression
              @block_pass = AST.create_node(raw_block.expression, lenv)
            else
              @anonymous_block_forwarding = true
            end
          else
            @block_pass = nil
            @block_tbl = raw_block.locals
            @block_multi_targets = {}
            @block_f_args = case raw_block.parameters
                            when Prism::BlockParametersNode
                              params = raw_block.parameters.parameters
                              req = params.requireds.each_with_index.map do |n, i|
                                if n.is_a?(Prism::MultiTargetNode)
                                  @block_multi_targets[i] = n
                                  nil
                                else
                                  n.name
                                end
                              end
                              opt = params.optionals.map {|n| n.name }
                              req + opt
                            when Prism::NumberedParametersNode
                              1.upto(raw_block.parameters.maximum).map { |n| :"_#{n}" }
                            when Prism::ItParametersNode
                              [:it]
                            when nil
                              []
                            else
                              raise "not supported yet: #{ raw_block.parameters.class }"
                            end
            ncref = CRef.new(lenv.cref.cpath, :instance, @mid, lenv.cref)
            nlenv = LocalEnv.new(@lenv.file_context, ncref, {}, @lenv.return_boxes)
            @block_opt_positional_defaults = []
            if raw_block.parameters.is_a?(Prism::BlockParametersNode)
              raw_block.parameters.parameters.optionals.each do |n|
                @block_opt_positional_defaults << AST.create_node(n.value, nlenv)
              end
            end
            @block_body = raw_block.body ? AST.create_node(raw_block.body, nlenv) : DummyNilNode.new(code_range, lenv)
          end
        end

        @yield = raw_node.type == :yield_node
      end

      attr_reader :recv, :mid, :mid_code_range, :yield
      attr_reader :positional_args, :splat_flags, :keyword_args
      attr_reader :block_tbl, :block_f_args, :block_opt_positional_defaults, :block_body, :block_pass, :anonymous_block_forwarding
      attr_reader :block_multi_targets
      attr_reader :safe_navigation, :forwarding_arguments

      def subnodes = { recv:, positional_args:, keyword_args:, block_opt_positional_defaults:, block_body:, block_pass: }
      def attrs = { mid:, splat_flags:, block_tbl:, block_f_args:, yield:, safe_navigation:, anonymous_block_forwarding:, forwarding_arguments: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @yield ? @lenv.get_var(:"*given_block") : @lenv.get_var(:"*self")

        if @safe_navigation
          allow_nil = NilFilter.new(genv, self, recv, true).next_vtx
          recv = NilFilter.new(genv, self, recv, false).next_vtx
        end

        if @forwarding_arguments
          forward_a_args = (@lenv.forward_args || raise).to_actual_arguments(genv, @changes, self)
          positional_args = forward_a_args.positionals
          splat_flags = forward_a_args.splat_flags
          keyword_args = forward_a_args.keywords
        else
          positional_args = @positional_args.map do |arg|
            if arg.is_a?(DummyNilNode)
              @lenv.get_var(:"*anonymous_rest")
            else
              arg.install(genv)
            end
          end
          splat_flags = @splat_flags
          keyword_args = @keyword_args ? @keyword_args.install(genv) : nil
        end

        if @block_body
          block_body = @block_body # kinda type annotationty
          block_tbl = @block_tbl || raise
          block_body.lenv.forward_args = @lenv.forward_args
          @lenv.locals.each {|var, vtx| block_body.lenv.locals[var] = vtx }
          block_tbl.each {|var| block_body.lenv.locals[var] = Source.new(genv.nil_type) }
          block_body.lenv.locals[:"*self"] = block_body.lenv.cref.get_self(genv)

          blk_f_args = []
          if @block_f_args
            @block_f_args.each do |arg|
              blk_f_args << block_body.lenv.new_var(arg, self)
            end
          end

          if @block_opt_positional_defaults && !@block_opt_positional_defaults.empty?
            req_count = blk_f_args.size - @block_opt_positional_defaults.size
            @block_opt_positional_defaults.each_with_index do |expr, i|
              @changes.add_edge(genv, expr.install(genv), blk_f_args[req_count + i])
            end
          end

          if @block_multi_targets
            @block_multi_targets.each do |idx, raw_multi_target|
              param_vtx = blk_f_args[idx]
              lefts = raw_multi_target.lefts.map do |n|
                block_body.lenv.new_var(n.is_a?(Prism::MultiTargetNode) ? nil : n.name, self)
              end
              @changes.add_masgn_box(genv, param_vtx, lefts, nil, nil)
            end
          end

          @lenv.locals.each do |var, vtx|
            block_body.lenv.set_var(var, vtx)
          end
          vars = []
          block_body.modified_vars(@lenv.locals.keys - block_tbl, vars)
          vars.uniq!
          vars.each do |var|
            vtx = @lenv.get_var(var)
            nvtx = vtx.new_vertex(genv, self)
            @lenv.set_var(var, nvtx)
            block_body.lenv.set_var(var, nvtx)
          end

          block_body.lenv.locals[:"*expected_block_ret"] = Vertex.new(self)
          block_body.install(genv)
          block_body.lenv.add_next_box(@changes.add_escape_box(genv, block_body.ret))

          vars.each do |var|
            @changes.add_edge(genv, block_body.lenv.get_var(var), @lenv.get_var(var))
          end

          blk_f_ary_arg = Vertex.new(self)
          # TODO: support splat "do |a, *b, c|"
          blk_f_args.each_with_index do |f_arg, i|
            elem_vtx = @changes.add_splat_box(genv, blk_f_ary_arg, i).ret
            @changes.add_edge(genv, elem_vtx, f_arg)
          end
          block = Block.new(self, blk_f_ary_arg, blk_f_args, block_body.lenv.next_boxes)
          blk_ty = Source.new(Type::Proc.new(genv, block))
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        elsif @anonymous_block_forwarding
          blk_ty = @lenv.get_var(:"*anonymous_block")
        elsif @forwarding_arguments
          blk_ty = forward_a_args.block
        end

        a_args = ActualArguments.new(positional_args, splat_flags, keyword_args, blk_ty)
        box = @changes.add_method_call_box(genv, recv, @mid, a_args, !@recv)

        block_body = @block_body
        if block_body && block_body.lenv.break_vtx
          ret = Vertex.new(self)
          @changes.add_edge(genv, box.ret, ret)
          @changes.add_edge(genv, block_body.lenv.break_vtx, ret)
        else
          ret = box.ret
        end

        if @safe_navigation
          @changes.add_edge(genv, allow_nil, ret)
        end

        if @mid == :[]= && @recv.is_a?(LocalVariableReadNode)
          key_node = @positional_args[0]
          if key_node.is_a?(SymbolNode)
            recv_vtx = @lenv.get_var(@recv.var)
            nvtx = @lenv.new_var(@recv.var, self)
            @changes.add_hash_aset_box(genv, recv_vtx, key_node.lit, ret, nvtx)
          end
        end

        ret
      end

      def block_last_stmt_code_range
        if @block_body
          if @block_body.is_a?(AST::StatementsNode)
            @block_body.stmts.last.code_range
          else
            @block_body.code_range
          end
        else
          nil
        end
      end

      def retrieve_at(pos, &blk)
        yield self if @mid_code_range && @mid_code_range.include?(pos)
        each_subnode do |subnode|
          next unless subnode
          subnode.retrieve_at(pos, &blk)
        end
      end

      def modified_vars(tbl, vars)
        if @mid == :[]= && @recv.is_a?(LocalVariableReadNode) && tbl.include?(@recv.var)
          key_node = @positional_args[0]
          vars << @recv.var if key_node.is_a?(SymbolNode)
        end
        subnodes.each do |key, subnode|
          next unless subnode
          if subnode.is_a?(AST::Node)
            if key == :block_body
              subnode.modified_vars(tbl - self.block_tbl, vars)
            else
              subnode.modified_vars(tbl, vars)
            end
          else
            subnode.each {|n| n.modified_vars(tbl, vars) }
          end
        end
      end
    end

    class CallNode < CallBaseNode
      def initialize(raw_node, lenv)
        recv = raw_node.receiver ? AST.create_node(raw_node.receiver, lenv) : nil
        mid = raw_node.name
        mid_code_range = lenv.code_range_from_node(raw_node.message_loc) if raw_node.message_loc
        raw_args = raw_node.arguments
        raw_block = raw_node.block
        super(raw_node, recv, mid, mid_code_range, raw_args, nil, raw_block, lenv)
      end

      def narrowings
        @narrowings ||= begin
          args = @positional_args
          case @mid
          when :is_a?
            if @recv.is_a?(LocalVariableReadNode) && args && args.size == 1
              [
                Narrowing.new({ @recv.var => Narrowing::IsAConstraint.new(args[0], false) }),
                Narrowing.new({ @recv.var => Narrowing::IsAConstraint.new(args[0], true) })
              ]
            elsif @recv.is_a?(InstanceVariableReadNode) && args && args.size == 1
              [
                Narrowing.new({ @recv.var => Narrowing::IsAConstraint.new(args[0], false) }),
                Narrowing.new({ @recv.var => Narrowing::IsAConstraint.new(args[0], true) })
              ]
            else
              super
            end
          when :nil?
            if @recv.is_a?(LocalVariableReadNode)
              [
                Narrowing.new({ @recv.var => Narrowing::NilConstraint.new(true) }),
                Narrowing.new({ @recv.var => Narrowing::NilConstraint.new(false) })
              ]
            elsif @recv.is_a?(InstanceVariableReadNode)
              [
                Narrowing.new({ @recv.var => Narrowing::NilConstraint.new(true) }),
                Narrowing.new({ @recv.var => Narrowing::NilConstraint.new(false) })
              ]
            else
              super
            end
          when :!
            then_narrowing, else_narrowing = @recv.narrowings
            [else_narrowing, then_narrowing]
          else
            super
          end
        end
      end
    end

    class SuperNode < CallBaseNode
      def initialize(raw_node,  lenv)
        raw_args = raw_node.arguments
        raw_block = raw_node.block
        super(raw_node, nil, :"*super", nil, raw_args, nil, raw_block, lenv)
      end
    end

    class ForwardingSuperNode < CallBaseNode
      def initialize(raw_node,  lenv)
        raw_args = nil
        raw_block = raw_node.block
        super(raw_node, nil, :"*super", nil, raw_args, nil, raw_block, lenv, forwarding_arguments: true)
      end
    end

    class YieldNode < CallBaseNode
      def initialize(raw_node, lenv)
        raw_args = raw_node.arguments
        super(raw_node, nil, :call, nil, raw_args, nil, nil, lenv)
      end
    end

    class OperatorNode < CallBaseNode
      def initialize(raw_node, recv, lenv)
        mid = raw_node.binary_operator
        mid_code_range = lenv.code_range_from_node(raw_node.binary_operator_loc)
        last_arg = AST.create_node(raw_node.value, lenv)
        super(raw_node, recv, mid, mid_code_range, nil, last_arg, nil, lenv)
      end
    end

    class IndexReadNode < CallBaseNode
      def initialize(raw_node, lenv)
        recv = AST.create_node(raw_node.receiver, lenv)
        mid = :[]
        mid_code_range = nil
        raw_args = raw_node.arguments
        super(raw_node, recv, mid, mid_code_range, raw_args, nil, nil, lenv)
      end
    end

    class IndexWriteNode < CallBaseNode
      def initialize(raw_node, rhs, lenv)
        recv = AST.create_node(raw_node.receiver, lenv)
        mid = :[]=
        mid_code_range = nil
        raw_args = raw_node.arguments
        @rhs = rhs
        super(raw_node, recv, mid, mid_code_range, raw_args, rhs, nil, lenv)
      end

      attr_reader :rhs
    end

    class CallReadNode < CallBaseNode
      def initialize(raw_node, lenv)
        recv = AST.create_node(raw_node.receiver, lenv)
        mid = raw_node.read_name
        mid_code_range = lenv.code_range_from_node(raw_node.message_loc)
        super(raw_node, recv, mid, mid_code_range, nil, nil, nil, lenv)
      end
    end

    class CallWriteNode < CallBaseNode
      def initialize(raw_node, rhs, lenv)
        recv = AST.create_node(raw_node.receiver, lenv)
        mid = raw_node.is_a?(Prism::CallTargetNode) ? raw_node.name : raw_node.write_name
        mid_code_range = lenv.code_range_from_node(raw_node.message_loc)
        @rhs = rhs
        super(raw_node, recv, mid, mid_code_range, nil, rhs, nil, lenv)
      end

      attr_reader :rhs
    end
  end
end
