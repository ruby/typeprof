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
      when :AND
        AND.new(raw_node, lenv)
      when :RESCUE
        RESCUE.new(raw_node, lenv)
      when :LIT
        lit, = raw_node.children
        LIT.new(raw_node, lenv, lit)
      when :STR
        str, = raw_node.children
        LIT.new(raw_node, lenv, str) # Using LIT is OK?
      when :TRUE
        LIT.new(raw_node, lenv, true) # Using LIT is OK?
      when :FALSE
        LIT.new(raw_node, lenv, false) # Using LIT is OK?
      when :LIST
        LIST.new(raw_node, lenv)
      when :IVAR
        IVAR.new(raw_node, lenv)
      when :IASGN
        IASGN.new(raw_node, lenv)
      when :LVAR
        LVAR.new(raw_node, lenv)
      when :LASGN
        LASGN.new(raw_node, lenv)
      when :DVAR
        DVAR.new(raw_node, lenv)
      when :DASGN
        DASGN.new(raw_node, lenv)
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
        @method_defs = nil
        @sites = nil
      end

      attr_reader :lenv, :prev_node, :ret

      def traverse(&blk)
        yield :enter, self
        subnodes.each_value do |subnode|
          subnode.traverse(&blk) if subnode
        end
        yield :leave, self
      end

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

      def method_defs
        @method_defs ||= Set[]
      end

      def add_method_def(genv, mdef)
        method_defs << mdef
        genv.add_method_def(mdef)
      end

      def sites
        @sites ||= Set[]
      end

      def add_site(site)
        sites << site
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
        unless @reused
          if @method_defs
            @method_defs.each do |mdef|
              genv.remove_method_def(mdef)
            end
          end
          if @sites
            @sites.each do |site|
              site.destroy(genv)
            end
          end
        end
        uninstall0(genv)
        if debug
          puts "uninstall leave: #{ self.class }@#{ code_range.inspect }"
        end
      end

      def uninstall0(genv)
        subnodes.each_value do |subnode|
          subnode.uninstall(genv) if subnode
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(self.class) && diff0(prev_node)
          subnodes.each do |key, subnode|
            prev_subnode = prev_node.send(key)
            if subnode && prev_subnode
              subnode.diff(prev_subnode)
              return unless subnode.prev_node
            else
              return if subnode != prev_subnode
            end
          end
          @prev_node = prev_node
        end
      end

      def diff0(_)
        true
      end

      def reuse
        @lenv = @prev_node.lenv
        @ret = @prev_node.ret
        @method_defs = @prev_node.method_defs
        @sites = @prev_node.sites

        subnodes.each_value do |subnode|
          subnode.reuse if subnode
        end
      end

      def hover(pos)
        if code_range.include?(pos)
          subnodes.each_value do |subnode|
            next unless subnode
            ret = subnode.hover(pos)
            return ret if ret
          end
        end
        return nil
      end

      def dump(dumper)
        s = dump0(dumper)
        if @sites && !@sites.empty?
          s += "\e[32m:#{ @sites.to_a.join(",") }\e[m"
        end
        s += "\e[34m:#{ @ret.inspect }\e[m"
        s
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        if @sites
          @sites.each do |site|
            vtxs << site.ret
            boxes << site
          end
        end
        subnodes.each_value do |subnode|
          subnode.get_vertexes_and_boxes(vtxs, boxes) if subnode
        end
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

      def subnodes
        # TODO: default expr for optional args
        { body: }
      end

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

      def diff0(prev_node)
        @tbl == prev_node.tbl && @args == prev_node.args
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
        super
      end
    end

    class BLOCK < Node
      def initialize(raw_node, lenv)
        super
        stmts = raw_node.children
        @stmts = stmts.map {|n| AST.create_node(n, lenv) }
      end

      def subnodes
        h = {}
        @stmts.each_with_index {|stmt, i| h[i] = stmt }
        h
      end

      attr_reader :stmts

      def install0(genv)
        ret = nil
        @stmts.each do |stmt|
          ret = stmt.install(genv)
        end
        ret
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

      def dump0(dumper)
        @stmts.map do |stmt|
          stmt.dump(dumper)
        end.join("\n")
      end
    end

    class ModuleNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope)
        super(raw_node, lenv)

        @cpath = AST.create_node(raw_cpath, lenv)
        @static_cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)

        # TODO: class Foo < Struct.new(:foo, :bar)

        if @static_cpath
          ncref = CRef.new(@static_cpath, true, lenv.cref)
          nlenv = LexicalScope.new(lenv.text_id, ncref, nil)
          @body = SCOPE.new(raw_scope, nlenv)
        else
          @body = nil
        end
      end

      attr_reader :name, :cpath, :static_cpath, :superclass_cpath, :static_superclass_cpath, :body

      def subnodes
        { cpath:, body: }
      end

      def diff0(prev_node)
        @static_cpath &&
        @static_cpath == prev_node.static_cpath &&
        @static_superclass_cpath == prev_node.static_superclass_cpath
      end
    end

    class MODULE < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
        raise
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
    end

    class CLASS < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_superclass, raw_scope = raw_node.children
        super(raw_node, lenv, raw_cpath, raw_scope)
        if raw_superclass
          @superclass_cpath = AST.create_node(raw_superclass, lenv)
          @static_superclass_cpath = AST.parse_cpath(raw_superclass, lenv.cref.cpath)
          @body = nil unless @static_superclass_cpath
        else
          @superclass_cpath = nil
          @static_superclass_cpath = [:Object]
        end
      end

      attr_reader :superclass_cpath

      def subnodes
        super.merge!({ superclass_cpath: })
      end

      def install0(genv)
        @cpath.install(genv)
        @superclass_cpath.install(genv) if @superclass_cpath
        if @static_cpath && @static_superclass_cpath
          genv.add_module(@static_cpath, self, @static_superclass_cpath)

          val = Source.new(Type::Module.new(@static_cpath))
          @cdef = ConstDef.new(@static_cpath[0..-2], @static_cpath[-1], self, val)
          genv.add_const_def(@cdef)

          @body.install(genv)
        else
          # TODO: show error
        end
      end

      def uninstall0(genv)
        if @static_cpath && @static_superclass_cpath
          genv.remove_const_def(@cdef)
          genv.remove_module(@static_cpath, self)
        end
        super
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
    end

    class CONST < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      def subnodes
        {}
      end

      attr_reader :cname

      def install0(genv)
        cref = @lenv.cref
        site = ConstReadSite.new(self, genv, cref, nil, @cname)
        add_site(site)
        site.ret
      end

      def diff0(prev_node)
        @cname == prev_node.cname
      end

      def dump0(dumper)
        "#{ @cname }"
      end
    end

    class COLON2 < Node
      def initialize(raw_node, lenv)
        super
        cbase_raw, @cname = raw_node.children
        @cbase = cbase_raw ? AST.create_node(cbase_raw, lenv) : nil
      end

      def subnodes
        { cbase: }
      end

      attr_reader :cbase, :cname

      def install0(genv)
        cbase = @cbase ? @cbase.install(genv) : nil
        site = ConstReadSite.new(self, genv, @lenv.cref, cbase, @cname)
        add_site(site)
        site.ret
      end

      def diff0(prev_node)
        @cname == prev_node.cname
      end

      def dump0(dumper)
        s = @cbase ? @cbase.dump(dumper) : ""
        s << "::#{ @cname }"
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

      def subnodes
        { cpath:, rhs: }
      end

      attr_reader :name, :cpath, :rhs, :static_cpath

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
        super
      end

      def diff0(prev_node)
        @static_cpath && @static_cpath == prev_node.static_cpath
      end

      def dump0(dumper)
        if @cpath
          "#{ @cpath.dump(dumper) } = #{ @rhs.dump(dumper) }"
        else
          "#{ @static_cpath[0] } = #{ @rhs.dump(dumper) }"
        end
      end
    end

    class DEFN < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @mid, raw_scope = raw_node.children

        ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
        nlenv = LexicalScope.new(lenv.text_id, ncref, nil)

        @scope = AST.create_node(raw_scope, nlenv)

        @reused = false
      end

      def subnodes
        @reused ? {} : { scope: }
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
          mdef = MethodDef.new(@lenv.cref.cpath, false, @mid, self, f_args, block, ret)
          add_method_def(genv, mdef)
        end
        Source.new(Type::Symbol.new(@mid))
      end

      def diff0(prev_node)
        @mid == prev_node.mid
      end

      def dump0(dumper)
        vtx = @scope.lenv.get_var(@scope.tbl[0])
        s = "def #{ @mid }(#{ @scope.tbl[0] }\e[34m:#{ vtx.inspect }\e[m)\n"
        s << @scope.dump(dumper).gsub(/^/, "  ") + "\n"
        s << "end"
      end
    end

    class BEGIN_ < Node
      def initialize(raw_node, lenv)
        super
        raise NotImplementedError if raw_node.children != [nil]
      end

      def subnodes
        {}
      end

      def install0(genv)
        # TODO
      end

      def uninstall0(genv)
        # TODO
      end

      def diff(prev_node)
        # TODO
      end

      def dump0(dumper)
        "begin; end"
      end
    end

    class CallNode < Node
      def initialize(raw_node, lenv, raw_recv, mid, raw_args)
        super(raw_node, lenv)
        @mid = mid
        @recv = AST.create_node(raw_recv, lenv) if raw_recv
        @a_args = A_ARGS.new(raw_args, lenv) if raw_args
        @block = nil
      end

      def subnodes
        { recv:, a_args:, block: }
      end

      attr_reader :recv, :mid, :a_args
      attr_reader :callsite
      attr_accessor :block

      def install0(genv)
        recv = @recv ? @recv.install(genv) : @lenv.get_self
        a_args = @a_args ? @a_args.install(genv) : []
        if @block
          blk_ret = @block.install(genv)
          blk_f_args = @block.get_args
          #block = @lenv.get_block(self)
          block = Block.new(@block, blk_f_args, blk_ret)
          blk_ty = Source.new(Type::Proc.new(block))
        end
        site = CallSite.new(self, genv, recv, @mid, a_args, blk_ty)
        add_site(site)
        site.ret
      end

      def diff0(prev_node)
        @mid == prev_node.mid
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

      def hover(pos)
        if @mid_code_range.include?(pos)
          @sites.to_a.first # TODO
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
        if @a_args
          dump_call("(#{ @recv.dump(dumper) } #{ @mid }", "#{ @a_args.dump(dumper) })")
        else
          dump_call("(#{ @mid }", "#{ @recv.dump(dumper) })")
        end
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

      def subnodes
        h = {}
        @positional_args.each_with_index {|n, i| h[i] = n }
        h
      end

      attr_reader :positional_args

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

    class ITER < Node
      def initialize(raw_node, lenv)
        super
        raw_call, raw_scope = raw_node.children
        @call = AST.create_node(raw_call, lenv)

        ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
        nlenv = LexicalScope.new(lenv.text_id, ncref, lenv)
        @call.block = AST.create_node(raw_scope, nlenv)
      end

      def subnodes
        { call: }
      end

      attr_reader :call, :block

      def install0(genv)
        @call.install(genv)
      end

      def dump0(dumper)
        @call.dump(dumper)
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

      def subnodes
        { cond:, then:, else: }
      end

      attr_reader :cond, :then, :else, :ret

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
        vtxs << @ret
        super
      end
    end

    class IF < BranchNode
    end

    class UNLESS < BranchNode
    end

    class AND < Node
      def initialize(raw_node, lenv)
        super
        raw_e1, raw_e2 = raw_node.children
        @e1 = AST.create_node(raw_e1, lenv)
        @e2 = AST.create_node(raw_e2, lenv)
      end

      def subnodes
        { e1:, e2: }
      end

      attr_reader :e1, :e2, :ret

      def install0(genv)
        @ret = Vertex.new("and", self)
        @e1.install(genv).add_edge(genv, @ret)
        @e2.install(genv).add_edge(genv, @ret)
        @ret
      end

      def dump0(dumper)
        "(#{ @e1.dump(dumper) } && #{ @e2.dump(dumper) })"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @ret
        super
      end
    end

    class RESCUE < Node
      def initialize(raw_node, lenv)
        super
        raw_body, _raw_rescue = raw_node.children
        @body = AST.create_node(raw_body, lenv)
        # TODO: raw_rescue
      end

      attr_reader :body

      def subnodes
        { body: }
      end

      def install0(genv)
        @body.install(genv)
      end

      def diff(prev_node)
        raise NotImplementedError
      end
    end

    class LIT < Node
      def initialize(raw_node, lenv, lit)
        super(raw_node, lenv)
        @lit = lit
      end

      def subnodes
        {}
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
        when Symbol
          Source.new(Type::Symbol.new(@lit))
        when TrueClass
          Source.new(Type::Instance.new([:TrueClss]))
        when FalseClass
          Source.new(Type::Instance.new([:FalseClss]))
        else
          raise "not supported yet: #{ @lit.inspect }"
        end
      end

      def diff0(prev_node)
        @lit.class == prev_node.lit.class && @lit == prev_node.lit
      end

      def dump0(dumper)
        @lit.inspect
      end
    end

    class LIST < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @elems = raw_node.children.compact.map {|n| AST.create_node(n, lenv) }
      end

      def subnodes
        h = {}
        @elems.each_with_index {|elem, i| h[i] = elem }
        h
      end

      attr_reader :elems

      def install0(genv)
        args = @elems.map {|elem| elem.install(genv) }
        site = ArrayAllocSite.new(self, genv, args)
        add_site(site)
        site.ret
      end

      def diff(prev_node)
        if prev_node.is_a?(LIST) && @elems.size == prev_node.elems.size
          @elems.zip(prev_node.elems) do |elem, prev_elem|
            elem.diff(prev_elem)
            return unless elem.prev_node
          end
          @prev_node = prev_node if match
        end
      end

      def dump0(dumper)
        "[#{ @elems.map {|elem| elem.dump(dumper) }.join(", ") }]"
      end
    end

    class IVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
        @iv = nil
      end

      def subnodes
        {}
      end

      attr_reader :var

      def install0(genv)
        site = IVarReadSite.new(self, genv, lenv.cref.cpath, lenv.cref.singleton, @var)
        add_site(site)
        site.ret
      end

      def diff0(prev_node)
        @var == prev_node.var
      end

      def hover(pos)
        code_range.include?(pos) ? @ret : nil
      end

      def dump0(dumper)
        "#{ @var }"
      end
    end

    class IASGN < Node
      def initialize(raw_node, lenv)
        super
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)
      end

      def subnodes
        { rhs: }
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
        super
      end

      def diff0(prev_node)
        @var == prev_node.var
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @vtx.inspect }\e[m = #{ @rhs.dump(dumper) }"
      end
    end

    class LVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
      end

      def subnodes
        {}
      end

      attr_reader :var

      def install0(genv)
        @lenv.get_var(@var) || raise
      end

      def diff0(prev_node)
        @var == prev_node.var
      end

      def hover(pos)
        code_range.include?(pos) ? @ret : nil
      end

      def dump0(dumper)
        "#{ @var }"
      end
    end

    class LASGN < Node
      def initialize(raw_node, lenv)
        super
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)
      end

      def subnodes
        { rhs: }
      end

      attr_reader :var, :rhs

      def install0(genv)
        val = @rhs.install(genv)
        @vtx = @lenv.def_var(@var, self)
        val.add_edge(genv, @vtx)
        val
      end

      def diff0(prev_node)
        @var == prev_node.var
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @vtx.inspect }\e[m = #{ @rhs.dump(dumper) }"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @vtx
        super
      end
    end

    class DVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
      end

      def subnodes
        {}
      end

      attr_reader :var

      def install0(genv)
        lenv = @lenv
        while lenv
          vtx = lenv.get_var(@var)
          return vtx if vtx
          lenv = lenv.outer
        end
      end

      def diff0(prev_node)
        @var == prev_node.var
      end

      def hover(pos)
        code_range.include?(pos) ? @ret : nil
      end

      def dump0(dumper)
        "#{ @var }"
      end
    end

    class DASGN < Node
      def initialize(raw_node, lenv)
        super
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)
      end

      def subnodes
        { rhs: }
      end

      attr_reader :var, :rhs

      def install0(genv)
        val = @rhs.install(genv)

        lenv = @lenv
        while lenv
          break if lenv.var_exist?(@var)
          lenv = lenv.outer
        end

        @vtx = lenv.def_var(@var, self)

        val.add_edge(genv, @vtx)
        val
      end

      def diff0(prev_node)
        @var == prev_node.var
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @vtx.inspect }\e[m = #{ @rhs.dump(dumper) }"
      end

      def get_vertexes_and_boxes(vtxs, boxes)
        vtxs << @vtx
        super
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
      @self = Source.new(@cref.get_self)
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

    def var_exist?(name)
      @tbl.key?(name)
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

    def get_self
      (@singleton ? Type::Module : Type::Instance).new(@cpath || [:Object])
    end
  end
end