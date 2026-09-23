module TypeProf::Core
  class AST
    # @lenv is the scope the block closes over; the body has its own LocalEnv.
    class BlockNode < Node
      def initialize(raw_node, lenv, mid)
        super(raw_node, lenv)

        @tbl = raw_node.locals
        ncref = CRef.new(lenv.cref.cpath, :instance, mid, lenv.cref)
        # A `return` in a block exits the enclosing method, so the body writes into
        # its return boxes. A lambda's `return` exits the lambda, so it gets its own.
        nlenv = LocalEnv.new(lenv.file_context, ncref, {}, lambda? ? [] : lenv.return_boxes)

        # parse_params with no parameters returns the canonical empty set, so the
        # readers below never have to ask whether there were any.
        @params = AST.parse_params(@tbl, nil, nlenv)
        @f_args = []
        @multi_targets = {}
        @opt_positional_defaults = []
        case raw_node.parameters
        when Prism::BlockParametersNode
          # `{ || ... }` (empty pipes) and `{ |; x| ... }` (block-local-only)
          # yield BlockParametersNode whose inner `parameters` is nil.
          @params = AST.parse_params(@tbl, raw_node.parameters.parameters, nlenv)
          @f_args = @params[:req_positionals] + @params[:opt_positionals]
          @multi_targets = @params[:req_multi_targets]
          @opt_positional_defaults = @params[:opt_positional_defaults]
        when Prism::NumberedParametersNode
          @f_args = 1.upto(raw_node.parameters.maximum).map {|n| :"_#{n}" }
        when Prism::ItParametersNode
          @f_args = [:it]
        when nil
        else
          raise "not supported yet: #{ raw_node.parameters.class }"
        end
        @body = raw_node.body ? AST.create_node(raw_node.body, nlenv) : DummyNilNode.new(code_range, lenv)
      end

      attr_reader :tbl, :f_args, :opt_positional_defaults, :body

      # FormalArguments carries vertices; the keyword names stay on the node, which
      # is where FormalArguments#pass_arguments looks them up.
      def req_keywords = @params[:req_keywords]
      def opt_keywords = @params[:opt_keywords]
      def rest_keywords = @params[:rest_keywords]
      def opt_keyword_defaults = @params[:opt_keyword_defaults]

      def subnodes = { opt_positional_defaults:, body: }
      # f_args covers only the parameters a block binds, so the rest have to be
      # compared too or an edit that only touches them looks like no edit at all.
      def attrs = { tbl:, f_args:, formal_names: }

      def formal_names
        @params.values_at(
          :req_positionals, :opt_positionals, :rest_positionals, :post_positionals,
          :req_keywords, :opt_keywords, :rest_keywords, :block,
        )
      end

      def install0(genv)
        blenv = @body.lenv
        blenv.forward_args = @lenv.forward_args
        @lenv.locals.each {|var, vtx| blenv.locals[var] = vtx }
        @tbl.each {|var| blenv.locals[var] = Source.new(genv.nil_type) }
        blenv.locals[:"*self"] = blenv.cref.get_self(genv)

        f_args = @f_args.map {|arg| blenv.new_var(arg, self) }

        req_count = f_args.size - @opt_positional_defaults.size
        @opt_positional_defaults.each_with_index do |expr, i|
          @changes.add_edge(genv, expr.install(genv), f_args[req_count + i])
        end

        install_multi_targets(genv, @multi_targets, f_args, blenv)
        formals = build_formals(genv, blenv, f_args)

        @lenv.locals.each do |var, vtx|
          blenv.set_var(var, vtx)
        end
        vars = []
        @body.modified_vars(@lenv.locals.keys - @tbl, vars)
        vars.uniq!
        vars.each do |var|
          vtx = @lenv.get_var(var)
          nvtx = vtx.new_vertex(genv, self)
          @lenv.set_var(var, nvtx)
          blenv.set_var(var, nvtx)
        end

        blenv.locals[:"*expected_block_ret"] = Vertex.new(self)
        # Present already when the lambda sits in a method; a top-level one still
        # needs it, or ReturnNode drops the returned value on the floor.
        blenv.locals[:"*expected_method_ret"] ||= Vertex.new(self) if lambda?
        @body.install(genv)
        blenv.add_next_box(@changes.add_escape_box(genv, @body.ret))

        if lambda?
          # `return` and `break` leave the lambda itself, so they reach the caller
          # of #call the same way the body's own value does.
          blenv.return_boxes.each {|box| blenv.add_next_box(box) }
          blenv.add_next_box(@changes.add_escape_box(genv, blenv.break_vtx)) if blenv.break_vtx
        end

        vars.each do |var|
          @changes.add_edge(genv, blenv.get_var(var), @lenv.get_var(var))
        end

        f_ary_arg = Vertex.new(self)
        # TODO: support splat "do |a, *b, c|"
        f_args.each_with_index do |f_arg, i|
          elem_vtx = @changes.add_splat_box(genv, f_ary_arg, i).ret
          @changes.add_edge(genv, elem_vtx, f_arg)
        end
        block = Block.new(self, f_ary_arg, f_args, blenv.next_boxes, formals)
        Source.new(Type::Proc.new(genv, block))
      end

      # A block is yielded to, and what a yielding method passes is the positional
      # list alone; there are no formals to bind beyond it.
      def build_formals(genv, blenv, f_args) = nil

      # Block-local variables shadow the outer ones, so writes to them are not
      # modifications of the enclosing scope.
      def modified_vars(tbl, vars)
        super(tbl - @tbl, vars)
      end

      # A block's `break` leaves the method that yielded, so the call it belongs to
      # takes the value; a lambda's `break` leaves the lambda and is wired above.
      def lambda? = false

      def break_vtx = lambda? ? nil : @body.lenv.break_vtx

      def ret_code_range = @body.ret_code_range
    end

    class CallBaseNode < Node
      def initialize(raw_node, recv, mid, mid_code_range_loc, raw_args, last_arg, raw_block, lenv, forwarding_arguments: false)
        super(raw_node, lenv)

        @recv = recv
        @mid = mid
        @mid_code_range_loc = mid_code_range_loc

        # args
        @positional_args = []
        @splat_flags = []
        @keyword_args = nil

        @block_pass = nil
        @block = nil
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
              @forwarding_arguments = :rest
            else
              args << raw_arg
              @splat_flags << false
            end
          end
          @positional_args = args.map {|arg| arg ? AST.create_node(arg, lenv) : nil }

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
            @block = BlockNode.new(raw_block, lenv, @mid)
          end
        end

        @yield = raw_node.type == :yield_node
      end

      attr_reader :recv, :mid, :yield

      def mid_code_range
        @mid_code_range ||= @lenv.code_range_from_node(@mid_code_range_loc) if @mid_code_range_loc
      end
      attr_reader :positional_args, :splat_flags, :keyword_args
      attr_reader :block, :block_pass, :anonymous_block_forwarding
      attr_reader :safe_navigation, :forwarding_arguments

      def subnodes = { recv:, positional_args:, keyword_args:, block:, block_pass: }
      def attrs = { mid:, splat_flags:, yield:, safe_navigation:, anonymous_block_forwarding:, forwarding_arguments: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @yield ? @lenv.get_var(:"*given_block") : @lenv.get_var(:"*self")

        if @safe_navigation
          allow_nil = NilFilter.new(genv, self, recv, true).next_vtx
          recv = NilFilter.new(genv, self, recv, false).next_vtx
        end

        if @forwarding_arguments
          forward_a_args = (@lenv.forward_args || raise).to_actual_arguments(
            genv,
            @changes,
            self,
            include_leading_positionals: @forwarding_arguments != :rest,
            activation_required: @forwarding_arguments == :rest,
          )
          # An anonymous rest cannot appear here: `bar(*, ...)` is a syntax error
          leading_args = @positional_args.map {|arg| arg.install(genv) }
          a_args = forward_a_args.prepend_positionals(leading_args, @splat_flags)
          a_args = a_args.with_keywords(@keyword_args.install(genv)) if @keyword_args
        else
          positional_args = @positional_args.map do |arg|
            if arg.nil?
              @lenv.get_var(:"*anonymous_rest")
            else
              arg.install(genv)
            end
          end
          a_args = ActualArguments.new(positional_args, @splat_flags, @keyword_args ? @keyword_args.install(genv) : nil, nil)
        end

        if @block
          blk_ty = @block.install(genv)
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        elsif @anonymous_block_forwarding
          blk_ty = @lenv.get_var(:"*anonymous_block")
        elsif @forwarding_arguments
          blk_ty = forward_a_args.block
        end

        if @forwarding_arguments
          a_args = a_args.with_block(blk_ty, omittable: !@block && !@block_pass && !@anonymous_block_forwarding)
        else
          a_args = a_args.with_block(blk_ty)
        end
        box = @changes.add_method_call_box(genv, recv, @mid, a_args, !@recv)

        if @block && @block.break_vtx
          ret = Vertex.new(self)
          @changes.add_edge(genv, box.ret, ret)
          @changes.add_edge(genv, @block.break_vtx, ret)
        else
          ret = box.ret
        end

        if @safe_navigation
          @changes.add_edge(genv, allow_nil, ret)
        end

        ret
      end

      def retrieve_at(pos, &blk)
        yield self if mid_code_range&.include?(pos)
        each_subnode do |subnode|
          next unless subnode
          subnode.retrieve_at(pos, &blk)
        end
      end

    end

    class CallNode < CallBaseNode
      def initialize(raw_node, lenv)
        recv = raw_node.receiver ? AST.create_node(raw_node.receiver, lenv) : nil
        mid = raw_node.name
        raw_args = raw_node.arguments
        raw_block = raw_node.block
        super(raw_node, recv, mid, raw_node.message_loc, raw_args, nil, raw_block, lenv)
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
        super(raw_node, nil, :"*super", nil, raw_args, nil, raw_block, lenv, forwarding_arguments: :all)
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
        last_arg = AST.create_node(raw_node.value, lenv)
        super(raw_node, recv, mid, raw_node.binary_operator_loc, nil, last_arg, nil, lenv)
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
        super(raw_node, recv, mid, raw_node.message_loc, nil, nil, nil, lenv)
      end
    end

    class CallWriteNode < CallBaseNode
      def initialize(raw_node, rhs, lenv)
        recv = AST.create_node(raw_node.receiver, lenv)
        mid = raw_node.is_a?(Prism::CallTargetNode) ? raw_node.name : raw_node.write_name
        @rhs = rhs
        super(raw_node, recv, mid, raw_node.message_loc, nil, rhs, nil, lenv)
      end

      attr_reader :rhs
    end
  end
end
