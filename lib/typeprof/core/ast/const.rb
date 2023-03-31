module TypeProf::Core
  class AST
    class ConstNode < Node
      def install0(genv)
        site = ConstReadSite.new(self, genv, @static_ret)
        add_site(:main, site)
        site.ret
      end

      def hover(pos)
        yield self if code_range.include?(pos)
      end
    end

    class CONST < ConstNode
      def initialize(raw_node, lenv, cname, toplevel)
        super(raw_node, lenv)
        @cname = cname
        @toplevel = toplevel
        @cdef = nil
      end

      attr_reader :cname, :toplevel, :cdef

      def attrs = { cname:, toplevel:, cdef: }

      def define0(genv)
        const = BaseConstRead.new(self, @cname, @toplevel ? CRef::Toplevel : @lenv.cref)
        genv.add_const_read(const)
        const
      end

      def undefine0(genv)
        genv.remove_const_read(@static_ret)
      end

      def dump0(dumper)
        "#{ @toplevel ? "::" : "" }#{ @cname }"
      end
    end

    class COLON2 < ConstNode
      def initialize(raw_node, lenv)
        super
        cbase_raw, @cname = raw_node.children
        @cbase = AST.create_node(cbase_raw, lenv)
      end

      def define0(genv)
        ScopedConstRead.new(self, @cname, @cbase.define(genv))
      end

      attr_reader :cbase, :cname

      def subnodes = { cbase: }
      def attrs = { cname: }

      def install0(genv)
        @cbase.install(genv)
        super
      end

      def dump0(dumper)
        "#{ @cbase.dump(dumper) }::#{ @cname }"
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

      def set_dummy_rhs(dummy_rhs)
        @dummy_rhs = dummy_rhs
      end

      attr_reader :cpath, :rhs, :static_cpath

      def subnodes = { cpath:, rhs: }
      def attrs = { static_cpath: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        dir = genv.resolve_const(@static_cpath)
        dir.defs << self
        dir
      end

      def undefine0(genv)
        genv.resolve_const(@static_cpath).defs.delete(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        @cpath.install(genv) if @cpath
        val = (@rhs || @dummy_rhs).install(genv)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super
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