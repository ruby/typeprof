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

      def retrieve_at(pos)
        yield self if code_range.include?(pos)
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

      def install0(genv)
        val = @rhs.install(genv)

        vtx = @lenv.new_var(@var, self)
        @changes.add_edge(genv, val, vtx)
        val
      end

      def retrieve_at(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
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
        box = @changes.add_ivar_read_box(genv, lenv.cref.cpath, lenv.cref.singleton, @var)
        @lenv.apply_read_filter(genv, self, @var, box.ret)
      end

      def retrieve_at(pos)
        yield self if code_range.include?(pos)
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

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_ivar(@lenv.cref.cpath, @lenv.cref.singleton, @var)
        mod.add_def(self)
        mod
      end

      def define_copy(genv)
        mod = genv.resolve_ivar(@lenv.cref.cpath, @lenv.cref.singleton, @var)
        mod.add_def(self)
        mod.remove_def(@prev_node)
        super(genv)
      end

      def undefine0(genv)
        mod = genv.resolve_ivar(@lenv.cref.cpath, @lenv.cref.singleton, @var)
        mod.remove_def(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        @changes.add_ivar_read_box(genv, @lenv.cref.cpath, @lenv.cref.singleton, @var)
        val = @rhs.install(genv)
        val = val.new_vertex(genv, self) # avoid multi-edge from val to static_ret.vtx
        @changes.add_edge(genv, val, @static_ret.vtx)
        val
      end

      def retrieve_at(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
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
        box = @changes.add_gvar_read_box(genv, @var)
        box.ret
      end

      def retrieve_at(pos)
        yield self if code_range.include?(pos)
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

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_gvar(@var)
        mod.add_def(self)
        mod
      end

      def define_copy(genv)
        mod = genv.resolve_gvar(@var)
        mod.add_def(self)
        mod.remove_def(@prev_node)
        super(genv)
      end

      def undefine0(genv)
        genv.resolve_gvar(@var).remove_def(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        val = @rhs.install(genv)
        @changes.add_edge(genv, val, @static_ret.vtx)
        val
      end

      def retrieve_at(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
      end
    end

    class ClassVariableWriteNode < Node
      def initialize(raw_node, rhs, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
        @var_code_range = TypeProf::CodeRange.from_node(raw_node.respond_to?(:name_loc) ? raw_node.name_loc : raw_node)
        @rhs = rhs
      end

      attr_reader :var, :var_code_range, :rhs

      def subnodes = { rhs: }
      def attrs = { var: }

      def define0(genv)
        @rhs.define(genv) if @rhs
        mod = genv.resolve_cvar(@lenv.cref.cpath, @var)
        mod.add_def(self)
        mod
      end

      def define_copy(genv)
        mod = genv.resolve_cvar(@lenv.cref.cpath, @var)
        mod.add_def(self)
        mod.remove_def(@prev_node)
        super(genv)
      end

      def undefine0(genv)
        mod = genv.resolve_cvar(@lenv.cref.cpath, @var)
        mod.remove_def(self)
        @rhs.undefine(genv) if @rhs
      end

      def install0(genv)
        @changes.add_cvar_read_box(genv, @lenv.cref.cpath, @var)
        val = @rhs.install(genv)
        val = val.new_vertex(genv, self) # avoid multi-edge from val to static_ret.vtx
        @changes.add_edge(genv, val, @static_ret.vtx)
        val
      end

      def retrieve_at(pos, &blk)
        yield self if @var_code_range && @var_code_range.include?(pos)
        super(pos, &blk)
      end
    end

    class ClassVariableReadNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @var = raw_node.name
      end

      attr_reader :var

      def attrs = { var: }

      def install0(genv)
        box = @changes.add_cvar_read_box(genv, lenv.cref.cpath, @var)
        @lenv.apply_read_filter(genv, self, @var, box.ret)
      end

      def retrieve_at(pos)
        yield self if code_range.include?(pos)
      end
    end

    class NumberedReferenceReadNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @var = :"$#{raw_node.number}"
      end

      attr_reader :var

      def attrs = { var: }

      def install0(genv)
        Source.new(genv.str_type)
      end
    end
  end
end
