module TypeProf
  class AST
    def self.parse(src, lenv)
      raw_node = RubyVM::AbstractSyntaxTree.parse(src, keep_tokens: true)
      AST.create_node(raw_node, lenv)
    end

    def self.create_node(raw_node, lenv)
      case raw_node.type
      when :SCOPE
        SCOPE.new(raw_node, lenv)
      when :BLOCK
        BLOCK.new(raw_node, lenv)
      when :MODULE
        MODULE.new(raw_node, lenv)
      when :CLASS
        CLASS.new(raw_node, lenv)
      when :CONST
        CONST.new(raw_node, lenv)
      when :COLON2
        COLON2.new(raw_node, lenv)
      when :CDECL
        CDECL.new(raw_node, lenv)
      when :DEFN
        DEFN.new(raw_node, lenv)
      when :BEGIN
        BEGIN_.new(raw_node, lenv)
      when :ITER
        ITER.new(raw_node, lenv)
      when :CALL
        CALL.new(raw_node, lenv)
      when :VCALL
        VCALL.new(raw_node, lenv)
      when :FCALL
        FCALL.new(raw_node, lenv)
      when :OPCALL
        OPCALL.new(raw_node, lenv)
      when :ATTRASGN
        ATTRASGN.new(raw_node, lenv)
      when :IF
        IF.new(raw_node, lenv)
      when :UNLESS
        UNLESS.new(raw_node, lenv)
      when :RESCUE
        RESCUE.new(raw_node, lenv)
      when :LIT
        LIT.new(raw_node, lenv)
      when :STR
        LIT.new(raw_node, lenv) # Using LIT is OK?
      when :IVAR
        IVAR.new(raw_node, lenv)
      when :IASGN
        IASGN.new(raw_node, lenv)
      when :LVAR
        LVAR.new(raw_node, lenv)
      when :LASGN
        LASGN.new(raw_node, lenv)
      else
        pp raw_node
        raise "not supported yet: #{ raw_node.type }"
      end
    end

    def self.parse_cpath(raw_node, base_cpath)
      names = []
      while raw_node
        case raw_node.type
        when :CONST
          name, = raw_node.children
          names << name
          break
        when :COLON2
          raw_node, name = raw_node.children
          names << name
        when :COLON3
          name, = raw_node.children
          names << name
          return names.reverse
        else
          return nil
        end
      end
      return base_cpath + names.reverse
    end

    class Node
      def initialize(raw_node, lenv)
        @raw_node = raw_node
        @lenv = lenv
        @raw_children = raw_node.children
        @prev_node = nil
        @ret = nil
        @text_di = lenv.text_id
      end

      attr_reader :lenv, :prev_node, :ret

      def code_range
        if @raw_node
          @code_range ||= CodeRange.new(
            CodePosition.new(@raw_node.first_lineno, @raw_node.first_column),
            CodePosition.new(@raw_node.last_lineno, @raw_node.last_column),
          )
        else
          pp self
          nil
        end
      end

      def install(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "install enter: #{ self.class }@#{ code_range.inspect }"
        end
        @ret = install0(genv)
        if debug
          puts "install leave: #{ self.class }@#{ code_range.inspect }"
        end
        @ret
      end

      def uninstall(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "uninstall enter: #{ self.class }@#{ code_range.inspect }"
        end
        uninstall0(genv)
        if debug
          puts "uninstall leave: #{ self.class }@#{ code_range.inspect }"
        end
      end

      def reuse
        @lenv = @prev_node.lenv
        @ret = @prev_node.ret
        reuse0
      end

      def hover(pos)
        if code_range.include?(pos)
          hover0(pos)
        end
      end

      def dump(dumper)
        dump0(dumper) + "\e[34m:#{ @ret.inspect }\e[m"
      end

      def pretty_print_instance_variables
        super - [:@raw_node, :@raw_children, :@lenv, :@prev_node]
      end
    end

    class SCOPE < Node
      def initialize(raw_node, lenv)
        raise if raw_node.type != :SCOPE
        super
        @tbl, raw_args, raw_body = raw_node.children

        @tbl.each do |v|
          lenv.allocate_var(v)
        end

        @args = raw_args ? raw_args.children : nil
        @body = raw_body ? AST.create_node(raw_body, lenv) : nil
      end

      attr_reader :tbl, :args, :body

      def install0(genv)
        if @args
          @args[0].times do |i|
            @lenv.def_var(@tbl[i], self)
          end
          blk = @args[9]
          @lenv.def_var(blk, self) if blk
        end
        @body ? @body.install(genv) : Source.new(Type::Instance.new([:NilClass]))
      end

      def get_args
        # XXX
        @tbl[0, @args[0]].map {|v| @lenv.get_var(v) }
      end

      def get_block
        @lenv.get_var(@args[9])
      end

      def uninstall0(genv)
        @body.uninstall0(genv) if @body
      end

      def diff(prev_node)
        if prev_node.is_a?(SCOPE) && @tbl == prev_node.tbl && @args == prev_node.args
          if @body
            @body.diff(prev_node.body)
            @prev_node = prev_node if @body.prev_node
          else
            @prev_node = prev_node if prev_node.body == nil
          end
        end
      end

      def reuse0
        @body.reuse if @body
      end

      def hover0(pos)
        @body.hover(pos) if @body
      end

      def dump(dumper) # intentionally not dump0
        @body ? @body.dump(dumper) : ""
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        if @args
          @args[0].times do |i|
            vtxs << @lenv.get_var(@tbl[i])
          end
          blk = @args[9]
          vtxs << @lenv.get_var(blk) if blk
        end
        @body.get_vertexes_and_boxes(vtxs, boxes) if @body
      end
    end

    class BLOCK < Node
      def initialize(raw_node, lenv)
        super
        stmts = raw_node.children
        @stmts = stmts.map {|n| AST.create_node(n, lenv) }
      end

      attr_reader :stmts

      def install0(genv)
        ret = nil
        @stmts.each do |stmt|
          ret = stmt.install(genv)
        end
        ret
      end

      def uninstall0(genv)
        @stmts.each do |stmt|
          stmt.uninstall(genv)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(BLOCK)
          i = 0
          while i < @stmts.size
            @stmts[i].diff(prev_node.stmts[i])
            if !@stmts[i].prev_node
              j1 = @stmts.size - 1
              j2 = prev_node.stmts.size - 1
              while j1 >= i
                @stmts[j1].diff(prev_node.stmts[j2])
                if !@stmts[j1].prev_node
                  return
                end
                j1 -= 1
                j2 -= 1
              end
              return
            end
            i += 1
          end
          if i == prev_node.stmts.size
            @prev_node = prev_node
          end
        end
      end

      def reuse0
        @stmts.each do |stmt|
          stmt.reuse
        end
      end

      def hover0(pos)
        @stmts.each do |stmt|
          ret = stmt.hover(pos)
          return ret if ret
        end
        nil
      end

      def dump0(dumper)
        @stmts.map do |stmt|
          stmt.dump(dumper)
        end.join("\n")
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @stmts.each do |stmt|
          stmt.get_vertexes_and_boxes(vtxs, boxes)
        end
      end
    end

    class ModuleNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)

        ncref = CRef.new(@static_cpath, true, lenv.cref)
        nlenv = LexicalScope.new(lenv.text_id, ncref, nil)

        @body = SCOPE.new(raw_scope, nlenv)
      end

      attr_reader :name, :cpath, :static_cpath, :superclass_cpath, :static_superclass_cpath, :body

      def diff(prev_node)
        if prev_node.is_a?(CLASS) &&
          @static_cpath && @static_cpath == prev_node.static_cpath &&
          @static_superclass_cpath == prev_node.static_superclass_cpath

          @body.diff(prev_node.body)
          @prev_node = prev_node if @body.prev_node
        end
      end
    end

    class MODULE < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
      end

      def install0(genv)
        @cpath_node.install(genv)
        genv.add_module(@static_cpath, self)
        @body.install(genv)
      end

      def uninstall0(genv)
        @body.uninstall(genv)
        genv.remove_module(@cpath)
      end

      def dump0(dumper)
        s = "module #{ @cpath.join("::") }\n" + s.gsub(/^/, "  ") + "\n"
        if @static_cpath
          s << @body.dump(dumper).gsub(/^/, "  ") + "\n"
        else
          s << "<analysis ommitted>\n"
        end
        s << "end"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @cpath.get_vertexes_and_boxes(vtxs, boxes)
        @body.get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class CLASS < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_superclass, raw_scope = raw_node.children
        if raw_superclass
          @superclass_cpath = AST.create_node(raw_superclass, lenv)
          @static_superclass_cpath = AST.parse_cpath(raw_superclass, lenv.cref.cpath)
        else
          @superclass_cpath = nil
          @static_superclass_cpath = [:Object]
        end
        super(raw_node, lenv, raw_cpath, raw_scope)
      end

      def install0(genv)
        @cpath.install(genv)
        @superclass_cpath.install(genv) if @superclass_cpath
        if @static_cpath && @static_superclass_cpath
          genv.add_module(@static_cpath, self, @static_superclass_cpath)

          val = Source.new(Type::Class.new(@static_cpath))
          @cdef = ConstDef.new(@static_cpath[0..-2], @static_cpath[-1], self, val)
          genv.add_const_def(@cdef)

          @body.install(genv)
        else
          # TODO: show error
        end
      end

      def uninstall0(genv)
        if @static_cpath
          @body.uninstall(genv)
          genv.remove_const_def(@cdef)
          genv.remove_module(@static_cpath, self)
        end
        @cpath.uninstall(genv)
        @superclass_cpath.uninstall(genv) if @superclass_cpath
      end

      def dump0(dumper)
        s = "class #{ @cpath.dump(dumper) }"
        s << " < #{ @superclass_cpath.dump(dumper) }" if @superclass_cpath
        s << "\n"
        if @static_cpath
          s << @body.dump(dumper).gsub(/^/, "  ") + "\n"
        else
          s << "<analysis ommitted>\n"
        end
        s << "end"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @cpath.get_vertexes_and_boxes(vtxs, boxes)
        @superclass_cpath.get_vertexes_and_boxes(vtxs, boxes) if @superclass_cpath
        @body.get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class CONST < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      attr_reader :cname, :readsite

      def install0(genv)
        cref = @lenv.cref
        @readsite = ConstReadSite.new(self, genv, cref, nil, @cname)
        @readsite.ret
      end

      def uninstall0(genv)
        @readsite.destroy(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(CONST) && @cname == prev_node.cname
          @prev_node = prev_node
        end
      end

      def reuse0
        @readsite = @prev_node.readsite
      end

      def dump0(dumper)
        "#{ @cname }\e[32m:#{ @readsite }\e[m"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @readsite.ret
        boxes << @readsite
      end
    end

    class COLON2 < Node
      def initialize(raw_node, lenv)
        super
        cbase_raw, @cname = raw_node.children
        @cbase = cbase_raw ? AST.create_node(cbase_raw, lenv) : nil
      end

      attr_reader :cname, :readsite

      def install0(genv)
        cbase = @cbase ? @cbase.install(genv) : nil
        @readsite = ConstReadSite.new(self, genv, @lenv.cref, cbase, @cname)
        @readsite.ret
      end

      def uninstall0(genv)
        @readsite.destroy(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(CONST) && @cname == prev_node.cname
          @prev_node = prev_node
        end
      end

      def reuse0
        @readsite = @prev_node.readsite
      end

      def dump0(dumper)
        s = @cbase ? @cbase.dump(dumper) : ""
        s << "::#{ @cname }\e[32m:#{ @readsite }\e[m"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @readsite.ret
        boxes << @readsite
        @cbase.get_vertexes_and_boxes(vtxs, boxes) if @cbase
      end
    end

    class CDECL < Node
      def initialize(raw_node, lenv)
        super
        children = raw_node.children
        if children.size == 2
          # C = expr
          @cpath = nil
          @static_cpath = lenv.cref.cpath + [children[0]]
          raw_rhs = children[1]
        else # children.size == 3
          # expr::C = expr
          @cpath = children[0]
          @static_cpath = AST.parse_cpath(@cpath, lenv.cref.cpath)
          raw_rhs = children[2]
        end
        @rhs = AST.create_node(raw_rhs, lenv)
      end

      attr_reader :name, :cpath, :static_cpath, :rhs

      def install0(genv)
        @cpath.install(genv) if @cpath
        val = @rhs.install(genv)
        if @static_cpath
          @cdef = ConstDef.new(@static_cpath[0..-2], @static_cpath[-1], self, val)
          genv.add_const_def(@cdef)
        end
        val
      end

      def uninstall0(genv)
        genv.remove_const_def(@cdef) if @static_cpath
        @cpath.uninstall(genv) if @cpath
        @rhs.uninstall(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(CDECL) &&
          @static_cpath && @static_cpath == prev_node.static_cpath
          @rhs.diff(prev_node.rhs)
          @prev_node = prev_node if @rhs.prev_node
        end
      end

      def dump0(dumper)
        if @cpath
          "#{ @cpath.dump(dumper) } = #{ @rhs.dump(dumper) }"
        else
          "#{ @static_cpath[0] } = #{ @rhs.dump(dumper) }"
        end
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @cpath.get_vertexes_and_boxes(vtxs, boxes)
        @rhs.get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class DEFN < Node
      def initialize(raw_node, lenv)
        ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
        nlenv = LexicalScope.new(lenv.text_id, ncref, nil)

        super(raw_node, nlenv)
        @mid, raw_scope = raw_node.children

        @scope = AST.create_node(raw_scope, @lenv)

        @reused = false
      end

      attr_reader :mid, :scope, :mdef
      attr_accessor :reused

      def install0(genv)
        if @prev_node
          reuse
          @prev_node.reused = true
        else
          # TODO: ユーザ定義 RBS があるときは検証する
          ret = @scope.install(genv)
          f_args = @scope.get_args
          block = @scope.get_block
          @mdef = MethodDef.new(@lenv.cref.cpath, false, @mid, self, f_args, block, ret)
          genv.add_method_def(@mdef)
        end
        Source.new(Type::Instance.new([:Symbol]))
      end

      def uninstall0(genv)
        unless @reused
          @scope.uninstall(genv)
          genv.remove_method_def(@mdef)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(DEFN) && @mid == prev_node.mid
          @scope.diff(prev_node.scope)
          @prev_node = prev_node if @scope.prev_node
        end
      end

      def reuse0
        @mdef = @prev_node.mdef
        @scope.reuse
      end

      def hover0(pos)
        # TODO: mid, f_args
        @scope.hover(pos)
      end

      def dump0(dumper)
        vtx = @scope.lenv.get_var(@scope.tbl[0])
        s = "def #{ @mid }(#{ @scope.tbl[0] }\e[34m:#{ vtx.inspect }\e[m)\n"
        s << @scope.dump(dumper).gsub(/^/, "  ") + "\n"
        s << "end"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @scope.get_vertexes_and_boxes(vtxs, boxes) unless @reused
      end
    end

    class BEGIN_ < Node
      def initialize(raw_node, lenv)
        super
        raise NotImplementedError if raw_node.children != [nil]
      end

      def install0(genv)
        # TODO
      end

      def uninstall0(genv)
        # TODO
      end

      def diff(prev_node)
        if prev_node.is_a?(BEGIN_)
          @prev_node = prev_node
        end
      end

      def dump0(dumper)
        "begin; end"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class CallNode < Node
      def initialize(raw_node, lenv, raw_recv, mid, raw_args)
        super(raw_node, lenv)
        @mid = mid
        @recv = AST.create_node(raw_recv, lenv) if raw_recv
        @a_args = A_ARGS.new(raw_args, lenv) if raw_args
      end

      attr_reader :recv, :mid, :a_args
      attr_reader :callsite
      attr_accessor :block

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @lenv.get_self
        a_args = @a_args ? @a_args.install(genv) : []
        if @block
          @block.install(genv)
          blk_ret = @block.install(genv)
          blk_f_args = @block.get_args
          #block = @lenv.get_block(self)
          block = BlockDef.new(@block, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(block))
        end
        @callsite = CallSite.new(self, genv, recv, @mid, a_args, blk_ty)
        @callsite.ret
      end

      def uninstall0(genv)
        @callsite.destroy(genv)
        @recv.uninstall(genv) if @recv
        @a_args.uninstall(genv) if @a_args
      end

      def diff(prev_node)
        if prev_node.is_a?(CALL) && @mid == prev_node.mid
          @recv.diff(prev_node.recv) if @recv
          @a_args.diff(prev_node.a_args) if @a_args
          @block.diff(prev_node.block) if @block
          if (@recv ? @recv.prev_node : true) &&
            (@a_args ? @a_args.prev_node : true) &&
            (@block ? @block.prev_node : true)

            @prev_node = prev_node
          end
        end
      end

      def reuse0
        @callsite = @prev_node.callsite
        @recv.reuse if @recv
        @a_args.reuse if @a_args
      end

      def hover0(pos)
        [@recv, @a_args, @block].each do |node|
          next unless node
          ret = node.hover(pos)
          return ret if ret
        end
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @callsite.ret
        boxes << @callsite
        @recv.get_vertexes_and_boxes(vtxs, boxes) if @recv
        @a_args.get_vertexes_and_boxes(vtxs, boxes) if @a_args
      end

      def dump_call(prefix, suffix)
        s = prefix + "\e[33m[#{ @callsite }]\e[m" + suffix
        if @block
          s << " do |<TODO>|\n"
          s << @block.dump(nil).gsub(/^/, "  ")
          s << "\nend"
        end
        s
      end
    end

    class CALL < CallNode
      def initialize(raw_node, lenv)
        raw_recv, mid, raw_args = raw_node.children
        super(raw_node, lenv, raw_recv, mid, raw_args)
      end

      def dump0(dumper)
        dump_call(@recv.dump(dumper) + ".#{ @mid }", "(#{ @a_args ? @a_args.dump(dumper) : "" })")
      end
    end

    class VCALL < CallNode
      def initialize(raw_node, lenv)
        mid, = raw_node.children
        super(raw_node, lenv, nil, mid, nil)
      end

      def dump0(dumper)
        dump_call(@mid.to_s, "")
      end
    end

    class FCALL < CallNode
      def initialize(raw_node, lenv)
        @mid, raw_args = raw_node.children

        super(raw_node, lenv, nil, mid, raw_args)

        token = raw_node.tokens.first
        if token[1] == :tIDENTIFIER && token[2] == @mid.to_s
          a = token[3]
          @mid_code_range = CodeRange.new(CodePosition.new(a[0], a[1]), CodePosition.new(a[2], a[3]))
        end
      end

      def hover0(pos)
        if @mid_code_range.include?(pos)
          @callsite
        else
          super
        end
      end

      def dump0(dumper)
        dump_call("#{ @mid }", "(#{ @a_args.dump(dumper) })")
      end
    end

    class OPCALL < CallNode
      def initialize(raw_node, lenv)
        raw_recv, mid, raw_args = raw_node.children
        super(raw_node, lenv, raw_recv, mid, raw_args)
      end

      def dump0(dumper)
        dump_call("(#{ @recv.dump(dumper) } #{ @mid }", "#{ @a_args.dump(dumper) })")
      end
    end

    class ATTRASGN < CallNode
      def initialize(raw_node, lenv)
        raw_recv, mid, raw_args = raw_node.children
        super(raw_node, lenv, raw_recv, mid, raw_args)
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

      def install0(genv)
        @positional_args.map do |node|
          node.install(genv)
        end
      end

      def uninstall0(genv)
        @positional_args.each do |node|
          node.uninstall(genv)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(A_ARGS) && @positional_args.size == prev_node.positional_args.size
          not_changed = true
          @positional_args.zip(prev_node.positional_args) do |node, prev_node|
            node.diff(prev_node)
            not_changed &&= node.prev_node
          end
          @prev_node = prev_node if not_changed
        end
      end

      def reuse0
        @positional_args.each {|node| node.reuse }
      end

      def hover0(pos)
        # TODO: op
        @recv.hover(pos) || @a_args.hover(pos)
      end

      def dump(dumper) # HACK: intentionally not dump0 because this node does not simply return a vertex
        @positional_args.map {|n| n.dump(dumper) }.join(", ")
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @positional_args.each do |n|
          n.get_vertexes_and_boxes(vtxs, boxes)
        end
      end
    end

    class ITER < Node
      def initialize(raw_node, lenv)
        super
        raw_call, raw_scope = raw_node.children
        @call = AST.create_node(raw_call, lenv)
        @call.block = AST.create_node(raw_scope, lenv)
      end

      attr_reader :call, :block

      def install0(genv)
        @call.install(genv)
      end

      def uninstall0(genv)
        @call.uninstall(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(ITER)
          @call.diff(prev_node.call)
          @prev_node = prev_node if @call.prev_node
        end
      end

      def reuse0
        @call.reuse
      end

      def hover0(pos)
        @call.hover(pos)
      end

      def dump0(dumper)
        @call.dump(dumper)
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @call.get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class BranchNode < Node
      def initialize(raw_node, lenv)
        super
        raw_cond, raw_then, raw_else = raw_node.children
        @cond = AST.create_node(raw_cond, lenv)
        @then = AST.create_node(raw_then, lenv)
        @else = raw_else ? AST.create_node(raw_else, lenv) : nil
      end

      attr_reader :cond, :then, :else, :block

      def install0(genv)
        @ret = Vertex.new("if", self)
        @cond.install(genv)
        @then.install(genv).add_edge(genv, @ret)
        if @else
          else_val = @else.install(genv)
        else
          else_val = Source.new(Type::Instance.new([:NilClass]))
        end
        else_val.add_edge(genv, @ret)
        @ret
      end

      def uninstall0(genv)
        @cond.uninstall(genv)
        @then.uninstall(genv)
        @else.uninstall(genv) if @else
      end

      def diff(prev_node)
        if prev_node.is_a?(IF)
          @cond.diff(prev_node.cond)
          @then.diff(prev_node.then)
          @else.diff(prev_node.else) if @else
          @prev_node = prev_node if @cond.prev_node && @then.prev_node && (@else ? @else.prev_node : true)
        end
      end

      def reuse0
        @cond.reuse
        @then.reuse
        @else.reuse if @else
      end

      def hover0(pos)
      end

      def dump0(dumper)
        s = "if #{ @cond.dump(dumper) }\n"
        s << @then.dump(dumper).gsub(/^/, "  ")
        if @else
          s << "\nelse\n"
          s << @else.dump(dumper).gsub(/^/, "  ")
        end
        s << "\nend"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @cond.get_vertexes_and_boxes(vtxs, boxes)
        @then.get_vertexes_and_boxes(vtxs, boxes)
        @else.get_vertexes_and_boxes(vtxs, boxes) if @else
      end
    end

    class IF < BranchNode
    end

    class UNLESS < BranchNode
    end

    class RESCUE < Node
      def initialize(raw_node, lenv)
        super
        raw_body, _raw_rescue = raw_node.children
        @body = AST.create_node(raw_body, lenv)
        # TODO: raw_rescue
      end

      def install0(genv)
        @body.install(genv)
      end

      def uninstall0(genv)
        @body.uninstall(genv)
      end

      def diff(prev_node)
        raise NotImplementedError
      end
    end

    class LIT < Node
      def initialize(raw_node, lenv)
        super
        lit, = raw_node.children
        @lit = lit
      end

      attr_reader :lit

      def install0(genv)
        case @lit
        when Integer
          Source.new(Type::Instance.new([:Integer]))
        when String
          Source.new(Type::Instance.new([:String]))
        when Float
          Source.new(Type::Instance.new([:Float]))
        else
          raise "not supported yet"
        end
      end

      def uninstall0(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(LIT) && @lit.class == prev_node.lit.class && @lit == prev_node.lit
          @prev_node = prev_node
        end
      end

      def reuse0
      end

      def hover0(pos)
      end

      def dump0(dumper)
        @lit.inspect
      end

      def get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class IVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
        @ivreadsite = nil
      end

      attr_reader :var, :ivreadsite

      def install0(genv)
        @ivreadsite = IVarReadSite.new(self, genv, lenv.cref.cpath, lenv.cref.singleton, @var)
        @ivreadsite.ret
      end

      def uninstall0(genv)
        @ivreadsite.destroy(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(IVAR) && @var == prev_node.var
          @prev_node = prev_node
        end
      end

      def reuse0
        @ivreadsite = prev_node.ivreadsite
      end

      def hover0(pos)
        @ret
      end

      def dump0(dumper)
        "#{ @var }"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @ivreadsite.ret
        boxes << @ivreadsite
      end
    end

    class IASGN < Node
      def initialize(raw_node, lenv)
        super
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)
      end

      attr_reader :var, :rhs

      def install0(genv)
        val = @rhs.install(genv)
        @ivdef = IVarDef.new(lenv.cref.cpath, lenv.cref.singleton, @var, self, val)
        genv.add_ivar_def(@ivdef)
        val
      end

      def uninstall0(genv)
        genv.remove_ivar_def(@ivdef)
        @rhs.uninstall(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(IASGN) && @var == prev_node.var
          @rhs.diff(prev_node.rhs)
          @prev_node = prev_node if @rhs.prev_node
        end
      end

      def reuse0
        @rhs.reuse
      end

      def hover0(pos)
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @vtx.inspect }\e[m = #{ @rhs.dump(dumper) }"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        @rhs.get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class LVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
      end

      attr_reader :var

      def install0(genv)
        @lenv.get_var(@var) || raise
      end

      def uninstall0(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(LVAR) && @var == prev_node.var
          @prev_node = prev_node
        end
      end

      def reuse0
      end

      def hover0(pos)
        @ret
      end

      def dump0(dumper)
        "#{ @var }"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
      end
    end

    class LASGN < Node
      def initialize(raw_node, lenv)
        super
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)
      end

      attr_reader :var, :rhs

      def install0(genv)
        val = @rhs.install(genv)
        @vtx = @lenv.def_var(@var, self)
        val.add_edge(genv, @vtx)
        val
      end

      def uninstall0(genv)
        @rhs.uninstall(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(LASGN) && @var == prev_node.var
          @rhs.diff(prev_node.rhs)
          @prev_node = prev_node if @rhs.prev_node
        end
      end

      def reuse0
        @rhs.reuse
      end

      def hover0(pos)
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @vtx.inspect }\e[m = #{ @rhs.dump(dumper) }"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @vtx
      end
    end
  end

  class LexicalScope
    def initialize(text_id, cref, outer)
      @text_id = text_id
      @cref = cref
      @tbl = {} # variable table
      @outer = outer
      # XXX
      @self = Source.new(Type::Instance.new(@cref.cpath || [:Object]))
    end

    attr_reader :text_id, :cref, :outer

    def allocate_var(name)
      @tbl[name] = nil
    end

    def def_var(name, node)
      raise unless @tbl.key?(name)
      @tbl[name] ||= Vertex.new("var:#{ name }", node)
    end

    def get_var(name)
      @tbl[name]
    end

    def get_self
      @self
    end
  end

  class CRef
    def initialize(cpath, singleton, outer)
      @cpath = cpath
      @singleton = singleton
      @outer = outer
    end

    attr_reader :cpath, :singleton, :outer

    def extend(cpath, singleton)
      CRef.new(cpath, singleton, self)
    end
  end
end