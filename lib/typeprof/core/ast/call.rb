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
          @block_f_args = raw_block_args ? raw_block_args.children : nil
          if @block_f_args
            @block_f_args[1] = nil # temporarily delete RubyVM::AST
          end
          ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
          nlenv = LocalEnv.new(@lenv.path, ncref, {})
          @block_body = AST.create_node(raw_block_body, nlenv)
        else
          @block_tbl = @block_f_args = @block_body = nil
        end

        @yield = raw_recv == false
      end

      attr_reader :recv, :mid, :positional_args, :block_tbl, :block_f_args, :block_body, :mid_code_range, :yield

      def subnodes = { recv:, block_body:, positional_args: }
      def attrs = { mid:, block_tbl:, block_f_args:, yield: }
      def code_ranges = { mid_code_range: }

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
          @lenv.locals.each {|var, vtx| @block_body.lenv.locals[var] = vtx }
          @block_tbl.each {|var| @block_body.lenv.locals[var] = Source.new(genv.nil_type) }
          @block_body.lenv.locals[:"*self"] = Source.new(@block_body.lenv.cref.get_self(genv))
          @block_body.lenv.locals[:"*block_ret"] = Vertex.new("block_ret", self)

          blk_f_args = []
          if @block_f_args
            @block_f_args[0].times do |i|
              blk_f_args << @block_body.lenv.new_var(@block_tbl[i], self)
            end
          end
          blk_ret = @block_body.lenv.get_var(:"*block_ret")

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

          @block_body.install(genv).add_edge(genv, blk_ret)

          vars.each do |var|
            @block_body.lenv.get_var(var).add_edge(genv, @lenv.get_var(var))
          end

          block = Block.new(@block_body, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(block))
        elsif @block_pass
          blk_ty = @block_pass.install(genv)
        end
        site = CallSite.new(self, genv, recv, @mid, positional_args, blk_ty, self.is_a?(FCALL))
        add_site(:main, site)
        site.ret
      end

      def hover(pos, &blk)
        yield self if @mid_code_range && @mid_code_range.include?(pos)
        each_subnode do |subnode|
          next unless subnode
          subnode.hover(pos, &blk)
        end
      end

      def diff(prev_node)
        return unless prev_node.is_a?(CallNode)
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

        if @positional_args && prev_node.positional_args
          if @positional_args.size == prev_node.positional_args.size
            @positional_args.zip(prev_node.positional_args) do |node, prev_node|
              node.diff(prev_node)
              return unless node.prev_node
            end
          else
            return
          end
        else
          return if @positional_args != prev_node.positional_args
        end

        @prev_node = prev_node
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
        Source.new(genv.nil_type)
      end

      def dump0(dumper)
        "super(...)"
      end
    end

    class YIELD < CallNode
      def initialize(raw_node, lenv)
        raw_args, = raw_node.children
        super(raw_node, raw_node, nil, lenv, false, :call, nil, raw_args)
      end

      def dump0(dumper)
        args = @positional_args ? @positional_args.map {|n| n.dump(dumper) }.join(", ") : ""
        dump_call("yield", "(#{ args })")
      end
    end
  end
end