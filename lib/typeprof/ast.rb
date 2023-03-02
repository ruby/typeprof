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
      when :CDECL
        CDECL.new(raw_node, lenv)
      when :DEFN
        DEFN.new(raw_node, lenv)
      when :BEGIN
        BEGIN_.new(raw_node, lenv)
      when :CALL
        CALL.new(raw_node, lenv)
      when :FCALL
        FCALL.new(raw_node, lenv)
      when :OPCALL
        OPCALL.new(raw_node, lenv)
      when :RESCUE
        RESCUE.new(raw_node, lenv)
      when :LIT
        LIT.new(raw_node, lenv)
      when :STR
        LIT.new(raw_node, lenv) # Using LIT is OK?
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
      # TODO: これは NODE の構造を覚えておくべき？
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
          raise "not supported"
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
        @val = nil
      end

      attr_reader :lenv, :prev_node, :val

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

      def run(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "run enter: #{ self.class }@#{ code_range.inspect }"
        end
        @val = run0(genv)
        if debug
          puts "run leave: #{ self.class }@#{ code_range.inspect }"
        end
        @val
      end

      def destroy(genv)
        debug = ENV["TYPEPROF_DEBUG"]
        if debug
          puts "destroy enter: #{ self.class }@#{ code_range.inspect }"
        end
        @val = destroy0(genv)
        if debug
          puts "destroy leave: #{ self.class }@#{ code_range.inspect }"
        end
        @val
      end

      def reuse
        @lenv = @prev_node.lenv
        @val = @prev_node.val
        reuse0
      end

      def hover(pos)
        if code_range.include?(pos)
          hover0(pos)
        end
      end

      def pretty_print_instance_variables
        super - [:@raw_node, :@raw_children, :@lenv]
      end
    end

    class SCOPE < Node
      def initialize(raw_node, lenv)
        raise if raw_node.type != :SCOPE
        super
        @tbl, raw_args, raw_body = raw_node.children

        @tbl.each do |v|
          lenv.add_var(v, Variable.new(v.to_s))
        end

        @args = raw_args ? raw_args.children : nil
        @body = AST.create_node(raw_body, lenv)
      end

      attr_reader :tbl, :args, :body

      def run0(genv)
        @body.run(genv)
      end

      def get_arg_tyvar
        # XXX
        @lenv.get_var(@tbl.first)
      end

      def destroy0(genv)
        @body.destroy0(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(SCOPE) && @tbl == prev_node.tbl && @args == prev_node.args
          @body.diff(prev_node.body)
          @prev_node = prev_node if @body.prev_node
        end
      end

      def reuse0
        @body.reuse
      end

      def hover0(pos)
        @body.hover(pos)
      end
    end

    class BLOCK < Node
      def initialize(raw_node, lenv)
        super
        stmts = raw_node.children
        @stmts = stmts.map {|n| AST.create_node(n, lenv) }
      end

      attr_reader :stmts

      def run0(genv)
        ret = nil
        @stmts.each do |stmt|
          ret = stmt.run(genv)
        end
        ret
      end

      def destroy0(genv)
        @stmts.each do |stmt|
          stmt.destroy(genv)
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

      def hover0(pos)
        @stmts.each do |stmt|
          ret = stmt.hover(pos)
          return ret if ret
        end
        nil
      end
    end

    class ModuleNode < Node
      def initialize(raw_node, lenv, raw_cpath, raw_scope)
        super(raw_node, lenv)

        @cpath = AST.parse_cpath(raw_cpath, lenv.cref.cpath)

        ncref = CRef.new(@cpath, true, lenv.cref)
        nlenv = LexicalScope.new(ncref, nil)

        @body = SCOPE.new(raw_scope, nlenv)
      end

      attr_reader :name, :cpath, :superclass_cpath, :body

      def diff(prev_node)
        if prev_node.is_a?(CLASS) && @cpath == prev_node.cpath && @superclass_cpath == prev_node.superclass_cpath
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

      def run0(genv)
        genv.add_module(@cpath)
        @body.run(genv)
      end

      def destroy0(genv)
        @body.destroy(genv)
        genv.remove_module(@cpath)
      end
    end

    class CLASS < ModuleNode
      def initialize(raw_node, lenv)
        raw_cpath, raw_superclass, raw_scope = raw_node.children
        if raw_superclass
          raise NotImplementedError
        else
          @superclass_cpath = [:Object]
        end
        super(raw_node, lenv, raw_cpath, raw_scope)
      end

      def run0(genv)
        genv.add_module(@cpath, self)
        genv.set_superclass(@cpath, @superclass_cpath)
        const_tyvar = genv.add_const(@cpath[0..-2], @cpath[-1], self)
        @tyval = Immutable.new(Type::Class.new(@cpath))
        @tyval.add_follower(genv, const_tyvar)
        @body.run(genv)
      end

      def destroy0(genv)
        @body.destroy(genv)
        genv.set_superclass(@cpath, nil)
        genv.remove_module(@cpath, self)
        # TODO: add_const???
        const_tyvar = genv.add_const(@cpath[0..-2], @cpath[-1], self)
        @tyval.remove_follower(genv, const_tyvar)
        genv.remove_const(@cpath[0..-2], @cpath[-1], self)
      end
    end

    class CONST < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      attr_reader :cname, :readsite

      def run0(genv)
        # TODO: ConstReadSite to refresh
        cref = @lenv.cref
        ret_tyvar = Variable.new("call:#{ @cname }")
        @readsite = ReadSite.new(self, cref, @cname, ret_tyvar)
        genv.add_readsite(@readsite)
        genv.add_run(@readsite) # needed...?
        ret_tyvar
      end

      def destroy0(genv)
        @readsite.destroy(genv)
        genv.remove_readsite(@readsite)
      end

      def diff(prev_node)
        if prev_node.is_a?(CONST) && @cname == prev_node.cname
          @prev_node = prev_node
        end
      end

      def reuse0
        @readsite = @prev_node.readsite
      end
    end

    class CDECL < Node
      def initialize(raw_node)
        super
        raw_const_path, raw_rhs = raw_node.children
        @const_path = Node.create_const_path(raw_const_path)
        @rhs = AST.create_node(raw_rhs)
      end

      attr_reader :name, :rhs

      def run0(genv, lenv)
        tyvar = @rhs.run(genv, lenv)
        env.add_const(@const_path, tyvar) # TODO: rhs
      end

      def destroy0(genv)
        raise NotImplementedError
      end

      def diff(prev_node)
        if prev_node.is_a?(CDECL) && @cpath == prev_node.cpath && @cpath_abs == prev_node.cpath_abs && @superclass_cpath == prev_node.superclass_cpath
          @body.diff(prev_node.body)
          @prev_node = prev_node if @body.prev_node
        end
      end
    end

    class DEFN < Node
      def initialize(raw_node, lenv)
        super
        @mid, raw_scope = raw_node.children

        ncref = CRef.new(lenv.cref.cpath, false, lenv.cref)
        nlenv = LexicalScope.new(ncref, nil)
        @body = AST.create_node(raw_scope, nlenv)

        @reused = false
      end

      attr_reader :mid, :body
      attr_accessor :reused

      def run0(genv)
        if @prev_node
          reuse
          @prev_node.reused = true
        else
          # TODO: ユーザ定義 RBS があるときは検証する
          ret_tyvar = @body.run(genv)
          arg_tyvar = @body.get_arg_tyvar
          @mdef = MethodDef.new(@lenv.cref.cpath, false, @mid, self, arg_tyvar, ret_tyvar)
          genv.add_method_def(@mdef)
        end
        Immutable.new(Type::Instance.new([:Symbol]))
      end

      def destroy0(genv)
        unless @reused
          @body.destroy(genv)
          genv.remove_method_def(@mdef)
        end
      end

      def diff(prev_node)
        if prev_node.is_a?(DEFN) && @mid == prev_node.mid
          @body.diff(prev_node.body)
          @prev_node = prev_node if @body.prev_node
        end
      end

      def reuse0
        @body.reuse
      end

      def hover0(pos)
        # TODO: mid, f_args
        @body.hover(pos)
      end
    end

    class BEGIN_ < Node
      def initialize(raw_node, lenv)
        super
        raise NotImplementedError if raw_node.children != [nil]
      end

      def run0(genv)
        # TODO
      end

      def destroy0(genv)
        # TODO
      end

      def diff(prev_node)
        if prev_node.is_a?(BEGIN_)
          @prev_node = prev_node
        end
      end
    end

    class CallNode < Node
      attr_reader :callsite

      def run_call(genv, recv_tyvar, mid, arg_tyvar)
        ret_tyvar = Variable.new("call:#{ mid }")
        @callsite = CallSite.new(self, recv_tyvar, mid, arg_tyvar, ret_tyvar)
        genv.add_callsite(@callsite)
        recv_tyvar.add_follower(genv, @callsite)
        arg_tyvar.add_follower(genv, @callsite)
        ret_tyvar
      end

      def destroy0(genv)
        @callsite.destroy(genv)
        genv.remove_callsite(@callsite)
      end
    end

    class CALL < CallNode
      def initialize(raw_node, lenv)
        super
        raw_recv, @mid, raw_args = raw_node.children
        @recv = AST.create_node(raw_recv, lenv)
        @a_args = A_ARGS.new(raw_args, lenv) if raw_args
      end

      attr_reader :op, :recv, :a_args

      def run0(genv)
        recv_tyvar = @recv.run(genv)

        # TODO: A_ARGS を引数1つと勝手に仮定してる
        #@a_args.run(genv)?
        arg = @a_args.positional_args[0]
        arg_tyvar = arg.run(genv)

        run_call(genv, recv_tyvar, @mid, arg_tyvar)
      end

      def destroy0(genv)
        @recv.destroy(genv)
        @a_args.destroy(genv)
        super
      end

      def diff(prev_node)
        if prev_node.is_a?(OPCALL) && @op == prev_node.op
          @recv.diff(prev_node.recv)
          @a_args.diff(prev_node.a_args)
          @prev_node = prev_node if @recv.prev_node && @a_args.prev_node
        end
      end

      def reuse0
        @callsite = @prev_node.callsite
        @recv.reuse
        @a_args.reuse
      end

      def hover0(pos)
        # TODO: op
        @recv.hover(pos) || @a_args.hover(pos)
      end
    end

    class FCALL < CallNode
      def initialize(raw_node, lenv)
        super
        @mid, raw_args = raw_node.children

        token = raw_node.tokens.first
        if token[1] == :tIDENTIFIER && token[2] == @mid.to_s
          a = token[3]
          @mid_code_range = CodeRange.new(
            CodePosition.new(a[0], a[1]),
            CodePosition.new(a[2], a[3]),
          )
        end

        @a_args = A_ARGS.new(raw_args, lenv)
      end

      attr_reader :mid, :a_args

      def run0(genv)
        # TODO
        recv_tyvar = @lenv.get_self

        # TODO: A_ARGS を引数1つと勝手に仮定してる
        #@a_args.run(genv, lenv)?
        arg = @a_args.positional_args[0]
        arg_tyvar = arg.run(genv)

        run_call(genv, recv_tyvar, @mid, arg_tyvar)
      end

      def destroy0(genv)
        @a_args.destroy(genv)
        super
      end

      def diff(prev_node)
        if prev_node.is_a?(FCALL) && @mid == prev_node.mid
          @a_args.diff(prev_node.a_args)
          @prev_node = prev_node if @a_args.prev_node
        end
      end

      def reuse0
        @callsite = @prev_node.callsite
        @a_args.reuse
      end

      def hover0(pos)
        if @mid_code_range.include?(pos)
          @callsite
        else
          @a_args.hover(pos)
        end
      end
    end

    class OPCALL < CallNode
      def initialize(raw_node, lenv)
        super
        raw_recv, @op, raw_args = raw_node.children
        @recv = AST.create_node(raw_recv, lenv)
        @a_args = A_ARGS.new(raw_args, lenv)
      end

      attr_reader :op, :recv, :a_args

      def run0(genv)
        recv_tyvar = @recv.run(genv)

        # TODO: A_ARGS を引数1つと勝手に仮定してる
        #@a_args.run(genv)?
        arg = @a_args.positional_args[0]
        arg_tyvar = arg.run(genv)

        run_call(genv, recv_tyvar, @op, arg_tyvar)
      end

      def destroy0(genv)
        @recv.destroy(genv)
        @a_args.destroy(genv)
        super
      end

      def diff(prev_node)
        if prev_node.is_a?(OPCALL) && @op == prev_node.op
          @recv.diff(prev_node.recv)
          @a_args.diff(prev_node.a_args)
          @prev_node = prev_node if @recv.prev_node && @a_args.prev_node
        end
      end

      def reuse0
        @callsite = @prev_node.callsite
        @recv.reuse
        @a_args.reuse
      end

      def hover0(pos)
        # TODO: op
        @recv.hover(pos) || @a_args.hover(pos)
      end
    end

    class A_ARGS < Node
      def initialize(raw_node, lenv)
        super
        @positional_args = []
        # TODO
        while raw_node
          case raw_node.type
          when :LIST
            arg, raw_node = raw_node.children
            @positional_args << AST.create_node(arg, lenv)
          else
            raise "not supported yet"
          end
        end
      end

      attr_reader :positional_args

      def destroy0(genv)
        @positional_args.each do |node|
          node.destroy(genv)
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
    end

    class RESCUE < Node
      def initialize(raw_node, lenv)
        super
        raw_body, _raw_rescue = raw_node.children
        @body = AST.create_node(raw_body, lenv)
        # TODO: raw_rescue
      end

      def run0(genv)
        @body.run(genv)
      end

      def destroy0(genv)
        @body.destroy(genv)
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

      def run0(genv)
        case @lit
        when Integer
          Immutable.new(Type::Instance.new([:Integer]))
        when String
          Immutable.new(Type::Instance.new([:String]))
        when Float
          Immutable.new(Type::Instance.new([:Float]))
        else
          raise "not supported yet"
        end
      end

      def destroy0(genv)
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
    end

    class LVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
      end

      attr_reader :var

      def run0(genv)
        @lenv.get_var(@var)
      end

      def destroy0(genv)
      end

      def diff(prev_node)
        if prev_node.is_a?(LVAR) && @var == prev_node.var
          @prev_node = prev_node
        end
      end

      def reuse0
      end

      def hover0(pos)
        @val
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

      def run0(genv)
        tyvar = @rhs.run(genv)
        tyvar.add_follower(genv, @lenv.get_var(@var))
        tyvar
      end

      def destroy0(genv)
        @rhs.destroy(genv)
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
    end
  end

  class LexicalScope
    def initialize(cref, outer)
      @cref = cref
      @tbl = {} # variable table
      @outer = outer
      # XXX
      @self = Immutable.new(Type::Instance.new(@cref.cpath))
    end

    attr_reader :cref, :outer

    def add_var(name, var)
      @tbl[name] = var
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