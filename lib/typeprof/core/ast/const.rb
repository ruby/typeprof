module TypeProf::Core
  class AST
    class CONST < Node
      def initialize(raw_node, lenv)
        super
        @cname, = raw_node.children
      end

      attr_reader :cname

      def attrs = { cname: }

      def define0(genv)
        const = BaseConstRead.new(self, @cname, @lenv.cref)
        genv.add_const_read(const)
        const
      end

      def undefine0(genv)
        genv.remove_const_read(@static_ret)
      end

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

      def define0(genv)
        if @cbase
          ScopedConstRead.new(self, @cname, @cbase.define(genv))
        else
          nil
        end
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

      def define0(genv)
        BaseConstRead.new(self, @cname, CRef::Toplevel)
      end

      attr_reader :cname

      def attrs = { cname: }

      def install0(genv)
        site = ConstReadSite.new(self, genv, CRef::Toplevel, nil, @cname)
        add_site(:main, site)
        site.ret
      end

      def dump0(dumper)
        "::#{ @cname }"
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
          @static_cpath = AST.parse_cpath(children[0], lenv.cref.cpath)
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
  end
end