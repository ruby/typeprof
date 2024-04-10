module TypeProf::Core
  class AST
    class LocalVariableReadNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
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

    class LocalVariableWriteNode < Node
      def initialize(raw_node, rhs, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
        @var_code_range = TypeProf::CodeRange.from_node(raw_node.respond_to?(:name_loc) ? raw_node.name_loc : raw_node)
        @rhs = rhs
      end

      attr_reader :var, :var_code_range, :rhs

      def subnodes = { rhs: }
      def attrs = { var: }
      def code_ranges = { var_code_range: }

      def install0(genv)
        val = @rhs.install(genv)

        vtx = @lenv.new_var(@var, self)
        val.add_edge(genv, vtx)
        val
      end

      def hover(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
      end

      def dump0(dumper)
        "#{ @var }\e[34m:#{ @lenv.get_var(@var).inspect }\e[m = #{ @rhs.dump(dumper) }"
      end

      def modified_vars(tbl, vars)
        vars << self.var if tbl.include?(self.var)
      end
    end

    class InstanceVariableReadNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
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

    class InstanceVariableWriteNode < Node
      def initialize(raw_node, rhs, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
        @var_code_range = TypeProf::CodeRange.from_node(raw_node.respond_to?(:name_loc) ? raw_node.name_loc : raw_node)
        @rhs = rhs
      end

      attr_reader :var, :var_code_range, :rhs

      def subnodes = { rhs: }
      def attrs = { var: }
      def code_ranges = { var_code_range: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_ivar(lenv.cref.cpath, lenv.cref.singleton, @var)
        mod.add_def(self)
        mod
      end

      def undefine0(genv)
        genv.resolve_ivar(lenv.cref.cpath, lenv.cref.singleton, @var).remove_def(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        site = IVarReadSite.new(self, genv, lenv.cref.cpath, lenv.cref.singleton, @var)
        add_site(:main, site)
        val = @rhs.install(genv)
        val = val.new_vertex(genv, "iasgn", self) # avoid multi-edge from val to static_ret.vtx
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super(genv)
      end

      def hover(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
      end

      def dump0(dumper)
        "#{ @var } = #{ @rhs.dump(dumper) }"
      end
    end

    class GlobalVariableReadNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
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

    class GlobalVariableWriteNode < Node
      def initialize(raw_node, rhs, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
        @var_code_range = TypeProf::CodeRange.from_node(raw_node.respond_to?(:name_loc) ? raw_node.name_loc : raw_node)
        @rhs = rhs
      end

      attr_reader :var, :var_code_range, :rhs

      def subnodes = { rhs: }
      def attrs = { var: }
      def code_ranges = { var_code_range: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_gvar(@var)
        mod.add_def(self)
        mod
      end

      def undefine0(genv)
        genv.resolve_gvar(@var).remove_def(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        val = @rhs.install(genv)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super(genv)
      end

      def hover(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
      end

      def dump0(dumper)
        "#{ @var } = #{ @rhs.dump(dumper) }"
      end
    end
  end
end
