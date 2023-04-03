module TypeProf::Core
  class AST
    class GVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
        @iv = nil
      end

      attr_reader :var

      def attrs = { var: }

      def install0(genv)
        site = GVarReadSite.new(self, genv, @var)
        add_site(:main, site)
        site.ret
      end

      def hover(pos)
        yield self if code_range.include?(pos)
      end

      def dump0(dumper)
        "#{ @var }"
      end
    end

    class GASGN < Node
      def initialize(raw_node, lenv)
        super
        var, raw_rhs = raw_node.children
        @var = var
        @rhs = raw_rhs ? AST.create_node(raw_rhs, lenv) : nil

        pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
        @var_code_range = AST.find_sym_code_range(pos, @var)
      end

      def set_dummy_rhs(dummy_rhs)
        @dummy_rhs = dummy_rhs
      end

      attr_reader :var, :rhs, :var_code_range, :dummy_rhs

      def subnodes = { rhs:, dummy_rhs: }
      def attrs = { var:  }
      def code_ranges = { var_code_range: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_gvar(@var)
        mod.defs << self
        mod
      end

      def undefine0(genv)
        genv.resolve_gvar(@var).defs.delete(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        val = (@rhs || @dummy_rhs).install(genv)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super
      end

      def hover(pos)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super
      end

      def dump0(dumper)
        "#{ @var } = #{ @rhs.dump(dumper) }"
      end
    end

    class IVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
        @iv = nil
      end

      attr_reader :var

      def attrs = { var: }

      def install0(genv)
        site = IVarReadSite.new(self, genv, lenv.cref.cpath, lenv.cref.singleton, @var)
        add_site(:main, site)
        @lenv.apply_read_filter(genv, self, @var, site.ret)
      end

      def hover(pos)
        yield self if code_range.include?(pos)
      end

      def dump0(dumper)
        "#{ @var }"
      end
    end

    class IASGN < Node
      def initialize(raw_node, lenv)
        super
        var, raw_rhs = raw_node.children
        @var = var
        @rhs = raw_rhs ? AST.create_node(raw_rhs, lenv) : nil

        pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
        @var_code_range = AST.find_sym_code_range(pos, @var)
      end

      def set_dummy_rhs(dummy_rhs)
        @dummy_rhs = dummy_rhs
      end

      attr_reader :var, :rhs, :var_code_range, :dummy_rhs

      def subnodes = { rhs:, dummy_rhs: }
      def attrs = { var: }
      def code_ranges = { var_code_range: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_ivar(lenv.cref.cpath, lenv.cref.singleton, @var)
        mod.defs << self
        mod
      end

      def undefine0(genv)
        genv.resolve_ivar(lenv.cref.cpath, lenv.cref.singleton, @var).defs.delete(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        site = IVarReadSite.new(self, genv, lenv.cref.cpath, lenv.cref.singleton, @var)
        add_site(:main, site)
        val = (@rhs || @dummy_rhs).install(genv)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super
      end

      def hover(pos)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super
      end

      def dump0(dumper)
        "#{ @var } = #{ @rhs.dump(dumper) }"
      end
    end

    class LVAR < Node
      def initialize(raw_node, lenv)
        super
        var, = raw_node.children
        @var = var
      end

      attr_reader :var

      def attrs = { var: }

      def install0(genv)
        @lenv.get_var(@var)
      end

      def hover(pos)
        yield self if code_range.include?(pos)
      end

      def dump0(dumper)
        "#{ @var }"
      end
    end

    class LASGN < Node
      def initialize(raw_node, lenv)
        super
        var, raw_rhs = raw_node.children
        @var = var
        @rhs = raw_rhs ? AST.create_node(raw_rhs, lenv) : nil

        pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
        @var_code_range = AST.find_sym_code_range(pos, @var)
      end

      def set_dummy_rhs(dummy_rhs)
        @dummy_rhs = dummy_rhs
      end

      attr_reader :var, :rhs, :var_code_range, :dummy_rhs

      def subnodes = { rhs:, dummy_rhs: }
      def attrs = { var: }
      def code_ranges = { var_code_range: }

      def install0(genv)
        val = (@rhs || @dummy_rhs).install(genv)

        vtx = @lenv.new_var(@var, self)
        val.add_edge(genv, vtx)
        val
      end

      def hover(pos)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @lenv.get_var(@var).inspect }\e[m = #{ @rhs.dump(dumper) }"
      end
    end

    class MASGN < Node
      def initialize(raw_node, lenv)
        super
        rhs, lhss = raw_node.children
        @rhs = AST.create_node(rhs, lenv)
        raise if lhss.type != :LIST # TODO: ARGSPUSH, ARGSCAT
        @lhss = lhss.children.compact.map {|node| AST.create_node(node, lenv) }
      end

      attr_reader :var, :rhs, :lhss, :var_code_range

      def subnodes = { rhs:, lhss: }

      def install0(genv)
        lhss = @lhss.map do |lhs|
          vtx = Vertex.new("masgn-rhs", self)
          last = @rhs.code_range.last
          lhs.set_dummy_rhs(DummyRHSNode.new(TypeProf::CodeRange.new(last, last), @lenv, vtx))
          vtx
        end
        rhs = @rhs.install(genv)
        site = MAsgnSite.new(self, genv, rhs, lhss)
        add_site(:main, site)
        @lhss.each {|lhs| lhs.install(genv) }
        site.ret
      end

      def hover(pos)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @lenv.get_var(@var).inspect }\e[m = #{ @rhs.dump(dumper) }"
      end
    end

    class OP_ASGN_OR < Node
      def initialize(raw_node, lenv)
        super
        raw_read, _raw_op, raw_write = raw_node.children
        @read = AST.create_node(raw_read, lenv)
        @write = AST.create_node(raw_write, lenv)
      end

      attr_reader :read, :write

      def subnodes = { read:, write: }

      def install0(genv)
        ret = @read.install(genv)
        @write.install(genv)
        ret
      end

      def dump0(dumper)
        "#{ @read.dump(dumper) } || #{ @write.dump(dumper) }"
      end
    end
  end
end