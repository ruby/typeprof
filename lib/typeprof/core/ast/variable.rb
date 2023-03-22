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
        cref = @lenv.cref
        site = ConstReadSite.new(self, genv, cref, nil, @cname)
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
        @rhs = AST.create_node(raw_rhs, lenv)
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
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)

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
        var, rhs = raw_node.children
        @var = var
        @rhs = AST.create_node(rhs, lenv)

        pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
        @var_code_range = AST.find_sym_code_range(pos, @var)
      end

      attr_reader :var, :rhs, :var_code_range

      def subnodes = { rhs: }
      def attrs = { var:, var_code_range: }

      def install0(genv)
        lenv = @lenv.resolve_var(@var)
        vtx = lenv ? lenv.get_var(@var) : @lenv.def_var(@var, self)

        val = @rhs.install(genv)
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
  end
end