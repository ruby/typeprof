module TypeProf::Core
  class AST
    class CONST < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      attr_reader :cname

      def attrs = { cname: }

      def install0(genv)
        site = ConstReadSite.new(self, genv, @lenv.cref, nil, @cname)
        add_site(:main, site)
        site.ret
      end

      def hover(pos)
        yield self if code_range.include?(pos)
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

      attr_reader :cbase, :cname

      def subnodes = { cbase: }
      def attrs = { cname: }

      def install0(genv)
        cbase = @cbase ? @cbase.install(genv) : nil
        site = ConstReadSite.new(self, genv, @lenv.cref, cbase, @cname)
        add_site(:main, site)
        site.ret
      end

      def dump0(dumper)
        s = @cbase ? @cbase.dump(dumper) : ""
        s << "::#{ @cname }"
      end
    end

    class COLON3 < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      attr_reader :cname

      def attrs = { cname: }

      def install0(genv)
        site = ConstReadSite.new(self, genv, CRef.new([], false, nil), nil, @cname)
        add_site(:main, site)
        site.ret
      end

      def dump0(dumper)
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
          @cpath = AST.create_node(children[0], lenv)
          @static_cpath = AST.parse_cpath(@cpath, lenv.cref.cpath)
          raw_rhs = children[2]
        end
        @rhs = raw_rhs ? AST.create_node(raw_rhs, lenv) : nil
      end

      attr_reader :cpath, :rhs, :static_cpath

      def subnodes = { cpath:, rhs: }
      def attrs = { static_cpath: }

      def install0(genv)
        @cpath.install(genv) if @cpath
        val = @rhs.install(genv)
        if @static_cpath
          cdef = ConstDef.new(@static_cpath[0..-2], @static_cpath[-1], self, val)
          add_def(genv, cdef)
        end
        val
      end

      def dump0(dumper)
        if @cpath
          "#{ @cpath.dump(dumper) } = #{ @rhs.dump(dumper) }"
        else
          "#{ @static_cpath[0] } = #{ @rhs.dump(dumper) }"
        end
      end
    end

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

      def subnodes = { rhs: }
      def attrs = { var:, var_code_range:, dummy_rhs: }

      def install0(genv)
        val = (@rhs || @dummy_rhs).install(genv)
        gvdef = GVarDef.new(@var, self, val)
        add_def(genv, gvdef)
        val
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
        site.ret
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

      attr_reader :var, :rhs, :var_code_range

      def subnodes = { rhs: }
      def attrs = { var:, var_code_range: }

      def install0(genv)
        val = @rhs.install(genv)
        ivdef = IVarDef.new(lenv.cref.cpath, lenv.cref.singleton, @var, self, val)
        add_def(genv, ivdef)
        val
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
        @lenv.resolve_var(@var).get_var(@var)
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

      def subnodes = { rhs: }
      def attrs = { var:, var_code_range:, dummy_rhs: }

      def install0(genv)
        lenv = @lenv.resolve_var(@var)
        vtx = lenv ? lenv.get_var(@var) : @lenv.def_var(@var, self)

        val = (@rhs || @dummy_rhs).install(genv)
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

    class DummyRHS
      def initialize(vtx)
        @vtx = vtx
      end

      def install(genv)
        @vtx
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

      def subnodes
        h = { rhs: }
        @lhss.each_with_index do |lhs, i|
          h[i] = lhs
        end
        h
      end

      def install0(genv)
        lhss = @lhss.map do |lhs|
          vtx = Vertex.new("masgn-rhs", self)
          lhs.set_dummy_rhs(DummyRHS.new(vtx))
          vtx
        end
        rhs = @rhs.install(genv)
        site = MAsgnSite.new(self, genv, rhs, lhss)
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