module TypeProf::Core
  class AST
    class META_INCLUDE < Node
      def initialize(raw_node, lenv)
        super
        _mid, raw_args = raw_node.children
        @args = raw_args.children.compact.map do |raw_arg|
          AST.create_node(raw_arg, lenv)
        end
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def subnodes
        h = {}
        @args.each_with_index do |arg, i|
          h[i] = arg
        end
        h
      end

      def define0(genv)
        dir = genv.resolve_cpath(@lenv.cref.cpath)
        @args.each do |arg|
          arg.define(genv)
          arg.static_ret.followers << dir if arg.static_ret
        end
        dir.add_include_def(genv, self)
        genv.add_static_eval_queue(:parent_modules_changed, @lenv.cref.cpath)
      end

      def undefine0(genv)
        dir = genv.resolve_cpath(@lenv.cref.cpath)
        dir.remove_include_def(genv, self)
        genv.add_static_eval_queue(:parent_modules_changed, @lenv.cref.cpath)
        super
      end

      def install0(genv)
        @args.each {|arg| arg.install(genv) }
        Source.new
      end

      def dump0(dumper)
        "attr_reader #{ @args.map {|arg| ":#{ arg }" }.join(", ") }"
      end
    end

    class META_ATTR_READER < Node
      def initialize(raw_node, lenv)
        super
        _mid, raw_args = raw_node.children
        @args = []
        raw_args.children.compact.each do |raw_arg|
          if raw_arg.type == :LIT
            lit, = raw_arg.children
            if lit.is_a?(::Symbol)
              @args << lit
            end
          end
        end
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def attrs = { args: }

      def install0(genv)
        i = 0
        @args.each do |arg|
          ivar_name = "@#{ arg }".to_sym # TODO: use DSYM
          site = IVarReadSite.new(self, genv, @lenv.cref.cpath, false, ivar_name)
          add_site([:attr_reader, i += 1], site)
          mdef = MethodDef.new(self, [], nil, site.ret)
          add_method_def(genv, @lenv.cref.cpath, false, arg, mdef)
        end
        Source.new
      end

      def dump0(dumper)
        "attr_reader #{ @args.map {|arg| ":#{ arg }" }.join(", ") }"
      end
    end

    class META_ATTR_ACCESSOR < Node
      def initialize(raw_node, lenv)
        super
        _mid, raw_args = raw_node.children
        @args = []
        raw_args.children.compact.each do |raw_arg|
          if raw_arg.type == :LIT
            lit, = raw_arg.children
            if lit.is_a?(::Symbol)
              @args << lit
            end
          end
        end
        # TODO: error for non-LIT
        # TODO: fine-grained hover
      end

      attr_reader :args

      def attrs = { args: }

      def define0(genv)
        @args.map do |arg|
          dir = genv.resolve_ivar(lenv.cref.cpath, false, "@#{ arg }".to_sym)
          dir.defs << self
          dir
        end
      end

      def undefine0(genv)
        @args.each do |arg|
          dir = genv.resolve_ivar(lenv.cref.cpath, false, @var)
          dir.defs.delete(self)
        end
      end

      def install0(genv)
        i = 0
        @args.zip(@static_ret) do |arg, ive|
          ivar_name = "@#{ arg }".to_sym # TODO: use DSYM
          site = IVarReadSite.new(self, genv, @lenv.cref.cpath, false, ivar_name)
          add_site(i += 1, site)
          mdef = MethodDef.new(self, [], nil, site.ret)
          add_method_def(genv, @lenv.cref.cpath, false, arg, mdef)

          vtx = Vertex.new("attr_writer-arg", self)
          vtx.add_edge(genv, ive.vtx)
          mdef = MethodDef.new(self, [vtx], nil, vtx)
          add_method_def(genv, @lenv.cref.cpath, false, "#{ arg }=".to_sym, mdef)
        end
        Source.new
      end

      def dump0(dumper)
        "attr_reader #{ @args.map {|arg| ":#{ arg }" }.join(", ") }"
      end
    end
  end
end