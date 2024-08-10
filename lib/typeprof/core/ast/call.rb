module TypeProf::Core
  class AST
    class CallBaseNode < Node
      def initialize(raw_node, recv, mid, mid_code_range, raw_args, last_arg, raw_block, lenv)
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
        @block_body = nil

        if raw_args
          args = []
          @splat_flags = []
          raw_args.arguments.each do |raw_arg|
            if raw_arg.is_a?(Prism::SplatNode)
              args << raw_arg.expression
              @splat_flags << true
            else
              args << raw_arg
              @splat_flags << false
            end
          end
          @positional_args = args.map {|arg| AST.create_node(arg, lenv) }

          if @positional_args.last.is_a?(TypeProf::Core::AST::HashNode) && @positional_args.last.keywords
            @keyword_args = @positional_args.pop
          end
        end

        @positional_args << last_arg if last_arg

        if raw_block
          if raw_block.type == :block_argument_node
            @block_pass = AST.create_node(raw_block.expression, lenv)
          else
            @block_pass = nil
            @block_tbl = raw_block.locals
            # TODO: optional args, etc.
            @block_f_args = case raw_block.parameters
                            when Prism::BlockParametersNode
                              raw_block.parameters.parameters.requireds.map {|n| n.is_a?(Prism::MultiTargetNode) ? nil : n.name }
                            when Prism::NumberedParametersNode
                              1.upto(raw_block.parameters.maximum).map { |n| :"_#{n}" }
                            when nil
                              []
                            else
                              raise "not supported yet: #{ raw_block.parameters.class }"
                            end
            ncref = CRef.new(lenv.cref.cpath, :instance, @mid, lenv.cref)
            nlenv = LocalEnv.new(@lenv.path, ncref, {}, @lenv.return_boxes)
            @block_body = raw_block.body ? AST.create_node(raw_block.body, nlenv) : DummyNilNode.new(code_range, lenv)
          end
        end

        @yield = raw_node.type == :yield_node
      end

      attr_reader :recv, :mid, :mid_code_range, :yield
      attr_reader :positional_args, :splat_flags, :keyword_args
      attr_reader :block_tbl, :block_f_args, :block_body, :block_pass

      def subnodes = { recv:, positional_args:, keyword_args:, block_body:, block_pass: }
      def attrs = { mid:, splat_flags:, block_tbl:, block_f_args:, yield: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @yield ? @lenv.get_var(:"*given_block") : @lenv.get_var(:"*self")

        positional_args = @positional_args.map do |arg|
          arg.install(genv)
        end

        keyword_args = @keyword_args ? @keyword_args.install(genv) : nil

        if @block_body
          @lenv.locals.each {|var, vtx| @block_body.lenv.locals[var] = vtx }
          @block_tbl.each {|var| @block_body.lenv.locals[var] = Source.new(genv.nil_type) }
          @block_body.lenv.locals[:"*self"] = @block_body.lenv.cref.get_self(genv)

          blk_f_args = []
          if @block_f_args
            @block_f_args.each do |arg|
              blk_f_args << @block_body.lenv.new_var(arg, self)
            end
          end

          @lenv.locals.each do |var, vtx|
            @block_body.lenv.set_var(var, vtx)
          end
          vars = []
          @block_body.modified_vars(@lenv.locals.keys - @block_tbl, vars)
          vars.uniq!
          vars.each do |var|
            vtx = @lenv.get_var(var)
            nvtx = vtx.new_vertex(genv, self)
            @lenv.set_var(var, nvtx)
            @block_body.lenv.set_var(var, nvtx)
          end

          e_ret = @block_body.lenv.locals[:"*expected_block_ret"] = Vertex.new(self)
          @block_body.install(genv)
          @block_body.lenv.add_next_box(@changes.add_escape_box(genv, @block_body.ret, e_ret))

          vars.each do |var|
            @changes.add_edge(genv, @block_body.lenv.get_var(var), @lenv.get_var(var))
          end

          blk_f_ary_arg = Vertex.new(self)
          @changes.add_masgn_box(genv, blk_f_ary_arg, blk_f_args, nil, nil) # TODO: support splat "do |a, *b, c|"
          block = Block.new(self, blk_f_ary_arg, blk_f_args, @block_body.lenv.next_boxes)
          blk_ty = Source.new(Type::Proc.new(genv, block))
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        end

        a_args = ActualArguments.new(positional_args, @splat_flags, keyword_args, blk_ty)
        box = @changes.add_method_call_box(genv, recv, @mid, a_args, !@recv)
        box.ret
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
        subnodes.each do |key, subnode|
          next unless subnode
          if key == :block_body
            subnode.modified_vars(tbl - self.block_tbl, vars)
          elsif subnode.is_a?(AST::Node)
            subnode.modified_vars(tbl, vars)
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
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.message_loc) if raw_node.message_loc
        raw_args = raw_node.arguments
        raw_block = raw_node.block
        super(raw_node, recv, mid, mid_code_range, raw_args, nil, raw_block, lenv)
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
        raw_args = nil # TODO: forward args properly
        raw_block = raw_node.block
        super(raw_node, nil, :"*super", nil, raw_args, nil, raw_block, lenv)
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
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.binary_operator_loc)
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
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.message_loc)
        super(raw_node, recv, mid, mid_code_range, nil, nil, nil, lenv)
      end
    end

    class CallWriteNode < CallBaseNode
      def initialize(raw_node, rhs, lenv)
        recv = AST.create_node(raw_node.receiver, lenv)
        mid = raw_node.is_a?(Prism::CallTargetNode) ? raw_node.name : raw_node.write_name
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.message_loc)
        @rhs = rhs
        super(raw_node, recv, mid, mid_code_range, nil, rhs, nil, lenv)
      end

      attr_reader :rhs
    end
  end
end
