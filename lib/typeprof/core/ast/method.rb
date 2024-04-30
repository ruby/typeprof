module TypeProf::Core
  class AST
    def self.get_rbs_comment_before(raw_node, lenv)
      comments = Fiber[:comments]
      i = comments.bsearch_index {|comment| comment.location.start_line >= raw_node.location.start_line } || comments.size
      lineno = raw_node.location.start_line
      rbs_comments = []
      while i > 0
        i -= 1
        lineno -= 1
        comment = comments[i]
        comment_loc = comment.location
        comment_text = comment_loc.slice
        if comment_loc.start_line == lineno && comment_text.start_with?("#:")
          rbs_comments[comment_loc.start_line] = " " * (comment_loc.start_column + 2) + comment_text[2..]
        else
          break
        end
      end
      return nil if rbs_comments.empty?
      rbs_comments = rbs_comments.map {|line| line || "" }.join("\n")
      method_type = RBS::Parser.parse_method_type(rbs_comments)
      if method_type
        AST.create_rbs_func_type(method_type, method_type.type_params, method_type.block, lenv)
      else
        nil
      end
    rescue RBS::ParsingError
      # TODO: report the error
      nil
    end

    def self.parse_params(tbl, raw_args, lenv)
      unless raw_args
        return {
          req_positionals: [],
          opt_positionals: [],
          opt_positional_defaults: [],
          rest_positionals: nil,
          post_positionals: [],
          req_keywords: [],
          opt_keywords: [],
          opt_keyword_defaults: [],
          rest_keywords: nil,
          block: nil,
        }
      end

      args_code_ranges = []
      req_positionals = []
      raw_args.requireds.each do |n|
        args_code_ranges << TypeProf::CodeRange.from_node(n.location)
        req_positionals << (n.is_a?(Prism::MultiTargetNode) ? nil : n.name)
      end

      # pre_init = args[1]

      opt_positionals = []
      opt_positional_defaults = []
      raw_args.optionals.each do |n|
        opt_positionals << n.name
        opt_positional_defaults << AST.create_node(n.value, lenv)
      end

      post_positionals = raw_args.posts.map {|n| (n.is_a?(Prism::MultiTargetNode) ? nil : n.name) }

      rest_positionals = raw_args.rest&.name

      req_keywords = []
      opt_keywords = []
      opt_keyword_defaults = []

      kw = raw_args.keywords
      if false
      while kw
        raise unless kw.type == :KW_ARG
        lasgn, kw = kw.children
        var, expr = lasgn.children
        if expr == :NODE_SPECIAL_REQUIRED_KEYWORD
          req_keywords << var
        else
          opt_keywords << var
          opt_keyword_defaults << AST.create_node(lasgn, lenv)
        end
      end

      rest_keywords = nil
      if args[8]
        raise unless args[8].type == :DVAR
        rest_keywords = args[8].children[0]
      end

      block = args[9]
      end
      block = raw_args.block.name if raw_args.block

      {
        req_positionals:,
        opt_positionals:,
        opt_positional_defaults:,
        rest_positionals:,
        post_positionals:,
        req_keywords:,
        opt_keywords:,
        opt_keyword_defaults:,
        rest_keywords:,
        block:,
        args_code_ranges:
      }
    end

    class DefNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        singleton = !!raw_node.receiver
        mid = raw_node.name
        mid_code_range = TypeProf::CodeRange.from_node(raw_node.name_loc)
        @tbl = raw_node.locals
        raw_args = raw_node.parameters
        raw_body = raw_node.body

        @rbs_method_type = AST.get_rbs_comment_before(raw_node, lenv)

        @singleton = singleton
        @mid = mid
        @mid_code_range = mid_code_range

        ncref = CRef.new(lenv.cref.cpath, @singleton, @mid, lenv.cref)
        nlenv = LocalEnv.new(@lenv.path, ncref, {})
        if raw_body
          @body = AST.create_node(raw_body, nlenv)
        else
          pos = code_range.last.left.left.left # before "end"
          cr = TypeProf::CodeRange.new(pos, pos)
          @body = DummyNilNode.new(cr, nlenv)
        end

        h = AST.parse_params(@tbl, raw_args, nlenv)
        @req_positionals = h[:req_positionals]
        @opt_positionals = h[:opt_positionals]
        @opt_positional_defaults = h[:opt_positional_defaults]
        @rest_positionals = h[:rest_positionals]
        @post_positionals = h[:post_positionals]
        @req_keywords = h[:req_keywords]
        @opt_keywords = h[:opt_keywords]
        @opt_keyword_defaults = h[:opt_keyword_defaults]
        @rest_keywords = h[:rest_keywords]
        @block = h[:block]

        # TODO: support opts, keywords, etc.
        @args_code_ranges = h[:args_code_ranges] || []

        @reused = false
      end

      attr_reader :singleton, :mid, :mid_code_range
      attr_reader :tbl
      attr_reader :req_positionals
      attr_reader :opt_positionals
      attr_reader :opt_positional_defaults
      attr_reader :rest_positionals
      attr_reader :post_positionals
      attr_reader :req_keywords
      attr_reader :opt_keywords
      attr_reader :opt_keyword_defaults
      attr_reader :rest_keywords
      attr_reader :block
      attr_reader :body
      attr_reader :rbs_method_type

      def subnodes = {
        body:,
        opt_positional_defaults:,
        opt_keyword_defaults:,
        rbs_method_type:,
      }
      def attrs = {
        singleton:,
        mid:,
        mid_code_range:,
        tbl:,
        req_positionals:,
        opt_positionals:,
        opt_positional_defaults:,
        rest_positionals:,
        post_positionals:,
        req_keywords:,
        opt_keywords:,
        opt_keyword_defaults:,
        rest_keywords:,
        block:,
      }

      def define0(genv)
        @opt_positional_defaults.each do |expr|
          expr.define(genv)
        end
        @opt_keyword_defaults.each do |expr|
          expr.define(genv)
        end
        @rbs_method_type.define(genv) if @rbs_method_type
        if @prev_node
          # TODO: if possible, replace this node itself with @prev_node
          @lenv = @prev_node.lenv
          @static_ret = @prev_node.static_ret
          @ret = @prev_node.ret
          @changes = @prev_node.changes
          @changes.sites.each_value do |site|
            if site.node != @prev_node
              pp site.node, self, @prev_node
              raise site.class.to_s
            end
            site.reuse(self)
          end
          @body.copy_code_ranges
          @body = @prev_node.body
          @prev_node.instance_variable_set(:@reused, true)
          @static_ret
        else
          super(genv)
        end
      end

      def install(genv) # NOT install0
        unless @prev_node
          if @rbs_method_type
            @changes.add_method_decl_site(genv, self, @lenv.cref.cpath, @singleton, @mid, [@rbs_method_type], false)
          end

          @tbl.each {|var| @body.lenv.locals[var] = Source.new(genv.nil_type) }
          @body.lenv.locals[:"*self"] = Source.new(@body.lenv.cref.get_self(genv))
          @body.lenv.locals[:"*ret"] = Vertex.new("method_ret", self)

          req_positionals = @req_positionals.map {|var| @body.lenv.new_var(var, self) }
          opt_positionals = @opt_positionals.map {|var| @body.lenv.new_var(var, self) }
          rest_positionals = @rest_positionals ? @body.lenv.new_var(@rest_positionals, self) : nil
          post_positionals = @post_positionals.map {|var| @body.lenv.new_var(var, self) }
          req_keywords = @req_keywords.map {|var| @body.lenv.new_var(var, self) }
          opt_keywords = @opt_keywords.map {|var| @body.lenv.new_var(var, self) }
          rest_keywords = @rest_keywords ? @body.lenv.new_var(@rest_keywords, self) : nil
          block = @block ? @body.lenv.new_var(@block, self) : nil

          @opt_positional_defaults.zip(opt_positionals) do |expr, vtx|
            @changes.add_edge(genv, expr.install(genv), vtx)
          end
          @opt_keyword_defaults.zip(opt_keywords) do |expr, vtx|
            @changes.add_edge(genv, expr.install(genv), vtx)
          end

          if block
            block = @body.lenv.set_var(:"*given_block", block)
          else
            block = @body.lenv.new_var(:"*given_block", self)
          end

          @body.install(genv) if @body

          ret = Vertex.new("ret", self)
          each_return_node do |node|
            @changes.add_edge(genv, node.ret, ret)
          end

          f_args = FormalArguments.new(
            req_positionals,
            opt_positionals,
            rest_positionals,
            post_positionals,
            req_keywords,
            opt_keywords,
            rest_keywords,
            block,
          )

          @changes.add_method_def_site(genv, self, @lenv.cref.cpath, @singleton, @mid, f_args, ret)
          @changes.reinstall(genv)
        end
        @ret = Source.new(Type::Symbol.new(genv, @mid))
      end

      def each_return_node
        yield @body
        traverse_children do |node|
          yield node.arg if node.is_a?(ReturnNode)
          true
        end
      end

      def hover(pos, &blk)
        if @rbs_method_type
          if @rbs_method_type.code_range.include?(pos) # annotation
            @rbs_method_type.hover(pos, &blk)
          end
        end
        @args_code_ranges.each_with_index do |cr, i|
          if cr.include?(pos)
            yield DummySymbolNode.new(@tbl[i], cr, @body.lenv.get_var(@tbl[i]))
            break
          end
        end
        super(pos, &blk)
      end

      def modified_vars(tbl, vars)
        # skip
      end
    end

    class AliasNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @new_mid = AST.create_node(raw_node.new_name, lenv)
        @old_mid = AST.create_node(raw_node.old_name, lenv)
      end

      attr_reader :new_mid, :old_mid

      def subnodes = { new_mid:, old_mid: }

      def install0(genv)
        @new_mid.install(genv)
        @old_mid.install(genv)
        if @new_mid.is_a?(SymbolNode) && @old_mid.is_a?(SymbolNode)
          new_mid = @new_mid.lit
          old_mid = @old_mid.lit
          me = genv.resolve_method(@lenv.cref.cpath, false, new_mid)
          me.add_alias(self, old_mid)
          me.add_run_all_callsites(genv)
        end
        Source.new(genv.nil_type)
      end

      def uninstall0(genv)
        if @new_mid.is_a?(SymbolNode) && @old_mid.is_a?(SymbolNode)
          new_mid = @new_mid.lit
          me = genv.resolve_method(@lenv.cref.cpath, false, new_mid)
          me.remove_alias(self)
          me.add_run_all_callsites(genv)
        end
        super(genv)
      end
    end
  end
end
