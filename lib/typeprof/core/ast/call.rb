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

          #last_hash_arg = @positional_args.last
          #if last_hash_arg.is_a?(HashNode) && last_hash_arg.keywords
          #  @positional_args.pop
          #  @keyword_args = last_hash_arg
          #end
        end
        @positional_args << last_arg if last_arg

        if raw_block
          if raw_block.type == :block_argument_node
            @block_pass = AST.create_node(raw_block.expression, lenv)
          else
            @block_pass = nil
            @block_tbl = raw_block.locals
            # TODO: optional args, etc.
            @block_f_args = raw_block.parameters ? raw_block.parameters.parameters.requireds.map {|n| n.is_a?(Prism::MultiTargetNode) ? nil : n.name } : []
            ncref = CRef.new(lenv.cref.cpath, false, @mid, lenv.cref)
            nlenv = LocalEnv.new(@lenv.path, ncref, {})
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
      def code_ranges = { mid_code_range: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @yield ? @lenv.get_var(:"*given_block") : @lenv.get_var(:"*self")

        positional_args = @positional_args.map do |arg|
          arg.install(genv)
        end

        keyword_args = @keyword_args ? @keyword_args.install(genv) : nil

        if @block_body
          @lenv.locals.each {|var, vtx| @block_body.lenv.locals[var] = vtx }
          @block_tbl.each {|var| @block_body.lenv.locals[var] = Source.new(genv.nil_type) }
          @block_body.lenv.locals[:"*self"] = Source.new(@block_body.lenv.cref.get_self(genv))

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
            nvtx = vtx.new_vertex(genv, "#{ vtx.show_name }'", self)
            @lenv.set_var(var, nvtx)
            @block_body.lenv.set_var(var, nvtx)
          end

          @block_body.install(genv)

          vars.each do |var|
            @block_body.lenv.get_var(var).add_edge(genv, @lenv.get_var(var))
          end

          blk_ret = Vertex.new("block_ret", self)
          each_return_node do |node|
            node.ret.add_edge(genv, blk_ret)
          end
          block = Block.new(self, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(genv, block))
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        end

        a_args = ActualArguments.new(positional_args, @splat_flags, keyword_args, blk_ty)
        site = CallSite.new(self, genv, recv, @mid, a_args, !@recv)
        add_site(:main, site)
        site.ret
      end

      def each_return_node
        yield @block_body
        traverse_children do |node|
          yield node.arg if node.is_a?(NextNode)
          !node.is_a?(CallSite) # do not entering nested blocks
        end
      end

      def hover(pos, &blk)
        yield self if @mid_code_range && @mid_code_range.include?(pos)
        each_subnode do |subnode|
          next unless subnode
          subnode.hover(pos, &blk)
        end
      end

      def diff(prev_node)
        return if self.class != prev_node.class
        return unless attrs.all? {|key, attr| attr == prev_node.send(key) }

        if @recv
          @recv.diff(prev_node.recv)
          return unless @recv.prev_node
        else
          return if @recv != prev_node.recv
        end

        return unless @splat_flags == prev_node.splat_flags

        @positional_args.zip(prev_node.positional_args) do |node, prev_node|
          node.diff(prev_node)
          return unless node.prev_node
        end

        if @keyword_args
          @keyword_args.diff(prev_node.keyword_args)
          return unless @keyword_args.prev_node
        else
          return unless @keyword_args == prev_node.keyword_args
        end

        if @block_pass
          @block_pass.diff(prev_node.block_pass)
          return unless @block_pass.prev_node
        else
          return unless @block_pass == prev_node.block_pass
        end

        if @block_body
          @block_body.diff(prev_node.block_body)
          return unless @block_body.prev_node
        else
          return if @block_body != prev_node.block_body
        end

        @prev_node = prev_node
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
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.message_loc)
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
        mid = raw_node.operator
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.operator_loc)
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
