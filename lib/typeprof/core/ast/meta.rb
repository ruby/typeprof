module TypeProf::Core
  class AST
    class ATTR_READER < Node
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
        @args.each do |arg|
          ivar_name = "@#{ arg }".to_sym # TODO: use DSYM
          site = IVarReadSite.new(self, genv, @lenv.cref.cpath, false, ivar_name)
          add_site(:attr_reader, site)
          mdef = MethodDef.new(@lenv.cref.cpath, false, arg, self, [], nil, site.ret)
          add_def(genv, mdef)
        end
        Source.new
      end

      def dump0(dumper)
        "attr_reader #{ @args.map {|arg| ":#{ arg }" }.join(", ") }"
      end
    end

    class ATTR_ACCESSOR < Node
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

      attr_reader :args, :ives

      def attrs = { args:, ives: }

      def define0(genv)
        @ives = @args.map do |arg|
          genv.resolve_ivar(lenv.cref.cpath, false, "@#{ arg }".to_sym).add_def(self)
        end
        nil
      end

      def undefine0(genv)
        @args.each do |arg|
          genv.resolve_ivar(lenv.cref.cpath, false, @var).remove_def(self)
        end
      end

      def install0(genv)
        i = 0
        @args.zip(@ives) do |arg, ive|
          ivar_name = "@#{ arg }".to_sym # TODO: use DSYM
          site = IVarReadSite.new(self, genv, @lenv.cref.cpath, false, ivar_name)
          add_site(i += 1, site)
          mdef = MethodDef.new(@lenv.cref.cpath, false, arg, self, [], nil, site.ret)
          add_def(genv, mdef)

          vtx = Vertex.new("attr_writer-arg", self)
          vtx.add_edge(genv, ive.vtx)
          mdef = MethodDef.new(@lenv.cref.cpath, false, "#{ arg }=".to_sym, self, [vtx], nil, vtx)
          add_def(genv, mdef)
        end
        Source.new
      end

      def dump0(dumper)
        "attr_reader #{ @args.map {|arg| ":#{ arg }" }.join(", ") }"
      end
    end
  end
end