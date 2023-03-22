module TypeProf::Core
  class AST
    class CallNode < Node
      def initialize(raw_node, raw_call, raw_block, lenv, raw_recv, mid, mid_code_range, raw_args)
        super(raw_node, lenv)

        @recv = AST.create_node(raw_recv, lenv) if raw_recv
        @mid = mid
        @mid_code_range = mid_code_range
        @a_args = A_ARGS.new(raw_args, lenv) if raw_args

        if raw_block
          @block_tbl, raw_block_args, raw_block_body = raw_block.children
          @block_f_args = raw_block_args.children
          ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
          nlenv = LexicalScope.new(lenv.text_id, self, ncref, lenv)
          @block_body = AST.create_node(raw_block_body, nlenv)
        else
          @block_tbl = @block_f_args = @block_body = nil
        end
      end

      attr_reader :recv, :mid, :a_args, :block_tbl, :block_f_args, :block_body, :mid_code_range

      def subnodes = { recv:, a_args:, block_body: }
      def attrs = { mid:, block_tbl:, block_f_args:, mid_code_range: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @lenv.get_self
        a_args = @a_args ? @a_args.install(genv) : []
        if @block_body
          blk_f_args = []
          @block_f_args[0].times do |i|
            blk_f_args << @block_body.lenv.def_var(@block_tbl[i], self)
          end
          blk_ret = @block_body.install(genv)
          block = Block.new(@block_body, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(block))
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

    class A_ARGS < Node
      def initialize(raw_node, lenv)
        super
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