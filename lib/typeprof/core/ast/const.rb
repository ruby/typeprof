module TypeProf::Core
  class AST
    class ConstantReadNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        case raw_node.type
        when :constant_read_node, :constant_operator_write_node, :constant_or_write_node, :constant_and_write_node
          @cbase = nil
          @toplevel = false
          @cname = raw_node.name
        when :constant_path_node, :constant_path_target_node
          if raw_node.parent
            @cbase = AST.create_node(raw_node.parent, lenv)
            @toplevel = false
          else
            @cbase = nil
            @toplevel = true
          end
          @cname = raw_node.child.name
        else
          raise raw_node.type.to_s
        end
      end

      attr_reader :cname, :cbase, :toplevel

      def attrs = { cname:, toplevel: }
      def subnodes = { cbase: }

      def define0(genv)
        if @cbase
          ScopedConstRead.new(@cname, @cbase.define(genv))
        else
          BaseConstRead.new(genv, @cname, @toplevel ? CRef::Toplevel : @lenv.cref)
        end
      end

      def undefine0(genv)
        @static_ret.destroy(genv)
      end

      def install0(genv)
        @cbase.install(genv) if @cbase
        site = ConstReadSite.new(self, genv, @static_ret)
        add_site(:main, site)
        site.ret
      end

      def hover(pos)
        yield self if code_range.include?(pos)
      end

      def dump0(dumper)
        @cname.to_s
      end
    end

    class ConstantWriteNode < Node
      def initialize(raw_node, rhs, lenv)
        super(raw_node, lenv)
        case raw_node.type
        when :constant_write_node, :constant_target_node, :constant_operator_write_node, :constant_or_write_node, :constant_and_write_node
          # C = expr
          @cpath = nil
          @static_cpath = lenv.cref.cpath + [raw_node.name]
        when :constant_path_write_node, :constant_path_operator_write_node, :constant_path_or_write_node, :constant_path_and_write_node
          # expr::C = expr
          @cpath = AST.create_node(raw_node.target, lenv)
          @static_cpath = AST.parse_cpath(raw_node.target, lenv.cref.cpath)
        when :constant_path_target_node
          # expr::C = expr
          @cpath = ConstantReadNode.new(raw_node, lenv)
          @static_cpath = AST.parse_cpath(raw_node, lenv.cref.cpath)
        else
          raise
        end
        @rhs = rhs
      end

      attr_reader :cpath, :rhs, :static_cpath

      def subnodes = { cpath:, rhs: }
      def attrs = { static_cpath: }

      def define0(genv)
        @cpath.define(genv) if @cpath
        @rhs.define(genv) if @rhs
        mod = genv.resolve_const(@static_cpath)
        mod.add_def(self)
        mod
      end

      def undefine0(genv)
        genv.resolve_const(@static_cpath).remove_def(self)
        @rhs.undefine(genv) if @rhs
        @cpath.undefine(genv) if @cpath
      end

      def install0(genv)
        @cpath.install(genv) if @cpath
        val = @rhs.install(genv)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super(genv)
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
