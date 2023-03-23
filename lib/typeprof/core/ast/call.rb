module TypeProf::Core
  class AST
    class CallNode < Node
      def initialize(raw_node, raw_call, raw_block, lenv, raw_recv, mid, mid_code_range, raw_args, raw_last_arg = nil)
        super(raw_node, lenv)

        @recv = AST.create_node(raw_recv, lenv) if raw_recv
        @mid = mid
        @mid_code_range = mid_code_range
        @a_args = nil
        @block_pass = nil
        if raw_args
          if raw_args.type == :BLOCK_PASS
            raw_args, raw_block_pass = raw_args.children
            @block_pass = AST.create_node(raw_block_pass, lenv)
          end
          if raw_args
            @a_args = A_ARGS.new(raw_args, raw_last_arg, lenv)
          end
        end

        if raw_block
          raise if @block_pass
          @block_tbl, raw_block_args, raw_block_body = raw_block.children
          @block_f_args = raw_block_args.children
          ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
          nlenv = LexicalScope.new(lenv.text_id, self, ncref, lenv)
          @block_body = AST.create_node(raw_block_body, nlenv)
        else
          @block_tbl = @block_f_args = @block_body = nil
        end

        @yield = raw_recv == false
      end

      attr_reader :recv, :mid, :a_args, :block_tbl, :block_f_args, :block_body, :mid_code_range, :yield

      def subnodes = { recv:, a_args:, block_body: }
      def attrs = { mid:, block_tbl:, block_f_args:, mid_code_range:, yield: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @yield ? @lenv.get_var(:&) : @lenv.get_self
        a_args = @a_args ? @a_args.install(genv) : []
        if @block_body
          blk_f_args = []
          @block_f_args[0].times do |i|
            blk_f_args << @block_body.lenv.def_var(@block_tbl[i], self)
          end
          blk_ret = @block_body.lenv.get_ret
          @block_body.install(genv).add_edge(genv, blk_ret)
          block = Block.new(@block_body, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(block))
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        end
        site = CallSite.new(self, genv, recv, @mid, a_args, blk_ty)
        add_site(:main, site)
        site.ret
      end

      def hover(pos)
        yield self if @mid_code_range && @mid_code_range.include?(pos)
        super
      end

      def dump_call(prefix, suffix)
        s = prefix + "\e[33m[#{ @sites.values.join(",") }]\e[m" + suffix
        if @block
          s << " do |<TODO>|\n"
          s << @block.dump(nil).gsub(/^/, "  ")
          s << "\nend"
        end
        s
      end
    end

    class CALL < CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        raw_recv, mid, raw_args = raw_call.children
        pos = TypeProf::CodePosition.new(raw_recv.last_lineno, raw_recv.last_column)
        mid_code_range = AST.find_sym_code_range(pos, mid)
        super(raw_node, raw_call, raw_block, lenv, raw_recv, mid, mid_code_range, raw_args)
      end

      def dump0(dumper)
        dump_call(@recv.dump(dumper) + ".#{ @mid }", "(#{ @a_args ? @a_args.dump(dumper) : "" })")
      end
    end

    class VCALL < CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        mid, = raw_node.children
        pos = TypeProf::CodePosition.new(raw_call.first_lineno, raw_call.first_column)
        mid_code_range = AST.find_sym_code_range(pos, mid)
        super(raw_node, raw_call, raw_block, lenv, nil, mid, mid_code_range, nil)
      end

      def dump0(dumper)
        dump_call(@mid.to_s, "")
      end
    end

    class FCALL < CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        mid, raw_args = raw_call.children
        pos = TypeProf::CodePosition.new(raw_call.first_lineno, raw_call.first_column)
        mid_code_range = AST.find_sym_code_range(pos, mid)
        super(raw_node, raw_call, raw_block, lenv, nil, mid, mid_code_range, raw_args)
      end

      def dump0(dumper)
        dump_call("#{ @mid }", "(#{ @a_args.dump(dumper) })")
      end
    end

    class OPCALL < CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        raw_recv, mid, raw_args = raw_call.children
        pos = TypeProf::CodePosition.new(raw_recv.last_lineno, raw_recv.last_column)
        mid_code_range = AST.find_sym_code_range(pos, mid)
        super(raw_node, raw_call, raw_block, lenv, raw_recv, mid, mid_code_range, raw_args)
      end

      def dump0(dumper)
        if @a_args
          dump_call("(#{ @recv.dump(dumper) } #{ @mid }", "#{ @a_args.dump(dumper) })")
        else
          dump_call("(#{ @mid }", "#{ @recv.dump(dumper) })")
        end
      end
    end

    class ATTRASGN < CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        raw_recv, mid, raw_args = raw_call.children
        # TODO
        pos = TypeProf::CodePosition.new(raw_recv.last_lineno, raw_recv.last_column)
        mid_code_range = AST.find_sym_code_range(pos, mid)
        super(raw_node, raw_call, raw_block, lenv, raw_recv, mid, mid_code_range, raw_args)
      end

      def dump0(dumper)
        dump_call("#{ @recv.dump(dumper) }.#{ @mid }", "(#{ @a_args.dump(dumper) })")
      end
    end

    class OP_ASGN_AREF < CallNode
      def initialize(raw_node, lenv)
        raw_recv, _raw_op, raw_args, raw_rhs = raw_node.children
        # Consider `ary[idx] ||= rhs` as `ary[idx] = rhs`
        super(raw_node, nil, nil, lenv, raw_recv, :[]=, nil, raw_args, raw_rhs)
      end

      def dump0(dumper)
        dump_call("#{ @recv.dump(dumper) }.#{ @mid }", "(#{ @a_args.dump(dumper) })")
      end
    end

    class SUPER < Node # CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        # completely dummy
      end

      def install0(genv)
        # completely dummy
        Source.new(Type.nil)
      end

      def dump0(dumper)
        dump("super(...)")
      end
    end

    class YIELD < CallNode
      def initialize(raw_node, lenv)
        raw_args, = raw_node.children
        super(raw_node, raw_node, nil, lenv, false, :call, nil, raw_args)
      end

      def dump0(dumper)
        dump_call("yield(#{ @a_args ? @a_args.dump(dumper) : "" })")
      end
    end

    class A_ARGS < Node
      def initialize(raw_node, raw_last_arg, lenv)
        super(raw_node, lenv)
        @positional_args = []
        # TODO
        case raw_node.type
        when :LIST
          args = raw_node.children.compact
          @positional_args = args.map {|arg| AST.create_node(arg, lenv) }
        when :ARGSPUSH, :ARGSCAT
          raise NotImplementedError
        else
          raise "not supported yet: #{ raw_node.type }"
        end
        if raw_last_arg
          @positional_args << AST.create_node(raw_last_arg, lenv)
        end
      end

      attr_reader :positional_args

      def subnodes
        h = {}
        @positional_args.each_with_index {|n, i| h[i] = n }
        h
      end

      def install0(genv)
        @positional_args.map do |node|
          node.install(genv)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(A_ARGS) && @positional_args.size == prev_node.positional_args.size
          @positional_args.zip(prev_node.positional_args) do |node, prev_node|
            node.diff(prev_node)
            return unless node.prev_node
          end
          @prev_node = prev_node
        end
      end

      def dump(dumper) # HACK: intentionally not dump0 because this node does not simply return a vertex
        @positional_args.map {|n| n.dump(dumper) }.join(", ")
      end
    end
  end
end