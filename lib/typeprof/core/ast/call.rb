module TypeProf::Core
  class AST
    class CallNode < Node
      def initialize(raw_node, raw_call, raw_block, lenv, raw_recv, mid, mid_code_range, raw_args, raw_last_arg = nil)
        super(raw_node, lenv)

        @recv = AST.create_node(raw_recv, lenv) if raw_recv
        @mid = mid
        @mid_code_range = mid_code_range
        @block_pass = nil
        if raw_args
          if raw_args.type == :BLOCK_PASS
            raw_args, raw_block_pass = raw_args.children
            @block_pass = AST.create_node(raw_block_pass, lenv)
          end
          if raw_args
            @positional_args = []
            # TODO
            case raw_args.type
            when :LIST
              args = raw_args.children.compact
              @positional_args = args.map {|arg| AST.create_node(arg, lenv) }
            when :ARGSPUSH, :ARGSCAT
              raise NotImplementedError
            else
              raise "not supported yet: #{ raw_args.type }"
            end
            if raw_last_arg
              @positional_args << AST.create_node(raw_last_arg, lenv)
            end
          end
        end

        if raw_block
          raise if @block_pass
          @block_tbl, raw_block_args, raw_block_body = raw_block.children
          @block_f_args = raw_block_args.children
          ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
          locals = lenv.locals.dup
          @block_tbl.each {|var| locals[var] = Source.new(Type.nil) }
          locals[:"*self"] = Source.new(ncref.get_self)
          locals[:"*block_ret"] = Vertex.new("block_ret", self)
          nlenv = LocalEnv.new(ncref, locals)
          @block_body = AST.create_node(raw_block_body, nlenv)
        else
          @block_tbl = @block_f_args = @block_body = nil
        end

        @yield = raw_recv == false
      end

      attr_reader :recv, :mid, :positional_args, :block_tbl, :block_f_args, :block_body, :mid_code_range, :yield

      def subnodes
        h = { recv:, block_body: }
        if @positional_args
          @positional_args.each_with_index {|n, i| h[i] = n }
        end
        h
      end
      def attrs = { mid:, block_tbl:, block_f_args:, mid_code_range:, yield: }

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @yield ? @lenv.get_var(:"*given_block") : @lenv.get_var(:"*self")
        if @positional_args
          positional_args = @positional_args.map do |node|
            node.install(genv)
          end
        else
          positional_args = []
        end
        if @block_body
          blk_f_args = []
          @block_f_args[0].times do |i|
            blk_f_args << @block_body.lenv.new_var(@block_tbl[i], self)
          end
          blk_ret = @block_body.lenv.get_var(:"*block_ret")

          @lenv.locals.each do |var, vtx|
            @block_body.lenv.set_var(var, vtx)
          end
          vars = Set[]
          @block_body.modified_vars(@lenv.locals.keys - @block_tbl, vars)
          vars.each do |var|
            vtx = @lenv.get_var(var)
            nvtx = vtx.new_vertex(genv, "#{ vtx.show_name }'", self)
            @lenv.set_var(var, nvtx)
            @block_body.lenv.set_var(var, nvtx)
          end

          @block_body.install(genv).add_edge(genv, blk_ret)

          vars.each do |var|
            @block_body.lenv.get_var(var).add_edge(genv, @lenv.get_var(var))
          end

          block = Block.new(@block_body, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(block))
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        end
        site = CallSite.new(self, genv, recv, @mid, positional_args, blk_ty)
        add_site(:main, site)
        site.ret
      end

      def hover(pos)
        yield self if @mid_code_range && @mid_code_range.include?(pos)
        super
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

        if @block_body
          @block_body.diff(prev_node.block_body)
          return unless @block_body.prev_node
        else
          return if @block_body != prev_node.block_body
        end

        if @positional_args
          if @positional_args.size == prev_node.positional_args.size
            @positional_args.zip(prev_node.positional_args) do |node, prev_node|
              node.diff(prev_node)
              return unless node.prev_node
            end
          end
        else
          return if @positional_args != prev_node.positional_args
        end
      end

      def dump_call(prefix, suffix)
        s = prefix + "\e[33m[#{ @sites.values.join(",") }]\e[m" + suffix
        if @block_body
          s << " do |<TODO>|\n"
          s << @block_body.dump(nil).gsub(/^/, "  ")
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
        args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
        dump_call(@recv.dump(dumper) + ".#{ @mid }", "(#{ args })")
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
        args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
        dump_call("#{ @mid }", "(#{ args })")
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
        if @positional_args
          args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
          dump_call("(#{ @recv.dump(dumper) } #{ @mid }", "#{ args })")
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
        args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
        dump_call("#{ @recv.dump(dumper) }.#{ @mid }", "(#{ args })")
      end
    end

    class OP_ASGN_AREF < CallNode
      def initialize(raw_node, lenv)
        raw_recv, _raw_op, raw_args, raw_rhs = raw_node.children
        # Consider `ary[idx] ||= rhs` as `ary[idx] = rhs`
        super(raw_node, nil, nil, lenv, raw_recv, :[]=, nil, raw_args, raw_rhs)
      end

      def dump0(dumper)
        args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
        dump_call("#{ @recv.dump(dumper) }.#{ @mid }", "(#{ args })")
      end
    end

    class SUPER < Node # CallNode
      def initialize(raw_node, raw_call, raw_block, lenv)
        # completely dummy
        super(raw_node, lenv)
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
        args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
        dump_call("yield(#{ args })")
      end
    end

    class A_ARGS
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