module TypeProf::Core
  class AST
    def self.get_rbs_comment_before(pos, lenv)
      tokens = Fiber[:tokens]
      i = tokens.bsearch_index {|_type, _str, code_range| pos <= code_range.first }
      if i
        comments = []
        while i > 0
          i -= 1
          type, str, cr = tokens[i]
          case type
          when :tSP
            # ignore
          when :tCOMMENT
            break unless str.start_with?("#:")
            comments[cr.first.lineno - 1] = " " * (cr.first.column + 2) + str[2..]
          else
            break
          end
        end
        return nil if comments.empty?
        comments = comments.map {|line| line || "" }.join("\n")
        method_type = RBS::Parser.parse_method_type(comments)
        if method_type
          AST.create_rbs_func_type(method_type, method_type.type_params, method_type.block, lenv)
        else
          nil
        end
      else
        nil
      end
    rescue RBS::ParsingError
      # TODO: report the error
      nil
    end

    def self.parse_params(tbl, raw_args, lenv)
      return [FormalArguments::Empty, [], []] unless raw_args

      args = raw_args.children

      req_positionals = tbl[0, args[0]]

      # pre_init = args[1]

      opt_positionals = []
      opt_positional_defaults = []
      opt = args[2]
      while opt
        raise unless opt.type == :OPT_ARG
        lasgn, opt = opt.children
        var, expr = lasgn.children
        opt_positionals << var
        opt_positional_defaults << AST.create_node(expr, lenv)
      end

      post_positionals = args[3] ? tbl[tbl.index(args[3]), args[4]] : []

      # post_init = args[5]

      rest_positionals = args[6]

      req_keywords = []
      opt_keywords = []
      opt_keyword_defaults = []

      kw = args[7]
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

      f_args = FormalArguments.new(
        req_positionals, opt_positionals, rest_positionals, post_positionals,
        req_keywords, opt_keywords, rest_keywords, block,
      )

      return [f_args, opt_positional_defaults, opt_keyword_defaults]
    end

    class DefNode < Node
      def initialize(raw_node, lenv, singleton, mid, raw_scope)
        super(raw_node, lenv)

        @rbs_method_type = AST.get_rbs_comment_before(code_range.first, lenv)

        @singleton = singleton
        @mid = mid

        raise unless raw_scope.type == :SCOPE
        @tbl, raw_args, raw_body = raw_scope.children

        ncref = CRef.new(lenv.cref.cpath, @singleton, @mid, lenv.cref)
        nlenv = LocalEnv.new(@lenv.path, ncref, {})
        if raw_body
          @body = AST.create_node(raw_body, nlenv)
        else
          pos = code_range.last.left.left.left # before "end"
          cr = TypeProf::CodeRange.new(pos, pos)
          @body = NilNode.new(cr, nlenv)
        end

        @f_args, @opt_positional_defaults, @opt_keyword_defaults =
          AST.parse_params(@tbl, raw_args, nlenv)

        @args_code_ranges = []
        @f_args.req_positionals.size.times do |i|
          pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
          @args_code_ranges << AST.find_sym_code_range(pos, @tbl[i])
          # TODO: support opts, keywords, etc.
        end

        @reused = false
      end

      attr_reader :singleton, :mid
      attr_reader :tbl
      attr_reader :f_args
      attr_reader :opt_positional_defaults
      attr_reader :opt_keyword_defaults
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
        tbl:,
        f_args:,
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
          @sites = @prev_node.sites
          @sites.each_value do |sites|
            sites.each do |site|
              if site.node != @prev_node
                pp site.node, self, @prev_node
                raise site.class.to_s
              end
              site.reuse(self)
            end
          end
          @body.copy_code_ranges
          @body = @prev_node.body
          @prev_node.instance_variable_set(:@reused, true)
        else
          super
        end
      end

      def install0(genv)
        unless @prev_node
          if @rbs_method_type
            mdecl = MethodDeclSite.new(self, genv, @lenv.cref.cpath, @singleton, @mid, [@rbs_method_type], false)
            add_site(:mdecl, mdecl)
          end

          @tbl.each {|var| @body.lenv.locals[var] = Source.new(genv.nil_type) }
          @body.lenv.locals[:"*self"] = Source.new(@body.lenv.cref.get_self(genv))
          @body.lenv.locals[:"*ret"] = Vertex.new("method_ret", self)

          f_arg_vtxs = {}
          @f_args.each_var do |var|
            f_arg_vtxs[var] = @body.lenv.new_var(var, self)
          end

          @f_args.opt_positionals.zip(@opt_positional_defaults) do |var, expr|
            expr.install(genv).add_edge(genv, f_arg_vtxs[var])
          end
          @f_args.opt_keywords.zip(@opt_keyword_defaults) do |var, expr|
            expr.install(genv).add_edge(genv, f_arg_vtxs[var])
          end

          if @f_args.block
            block = @body.lenv.set_var(:"*given_block", f_arg_vtxs[@f_args.block])
          else
            block = @body.lenv.new_var(:"*given_block", self)
          end

          @body.install(genv) if @body

          ret = Vertex.new("ret", self)
          each_return_node do |node|
            node.ret.add_edge(genv, ret)
          end
          mdef = MethodDefSite.new(self, genv, @lenv.cref.cpath, @singleton, @mid, @f_args, f_arg_vtxs, block, ret)
          add_site(:mdef, mdef)
        end
        Source.new(Type::Symbol.new(genv, @mid))
      end

      def each_return_node
        yield @body
        traverse_children do |node|
          yield node.arg if node.is_a?(RETURN)
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
        super
      end

      def dump0(dumper)
        s = "def #{ @mid }(#{
          (0..@args[0]-1).map {|i| "#{ @tbl[i] }:\e[34m:#{ @body.lenv.get_var(@tbl[i]) }\e[m" }.join(", ")
        })\n"
        s << @body.dump(dumper).gsub(/^/, "  ") + "\n" if @body
        s << "end"
      end

      def modified_vars(tbl, vars)
        # skip
      end
    end

    class DEFN < DefNode
      def initialize(raw_node, lenv)
        mid, raw_scope = raw_node.children
        super(raw_node, lenv, false, mid, raw_scope)
      end
    end

    class DEFS < DefNode
      def initialize(raw_node, lenv)
        raw_recv, mid, raw_scope = raw_node.children
        @recv = AST.create_node(raw_recv, lenv)
        unless @recv.is_a?(SELF)
          puts "???"
        end
        super(raw_node, lenv, true, mid, raw_scope)
      end
    end

    class ALIAS < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        raw_new_mid, raw_old_mid = raw_node.children
        @new_mid = AST.create_node(raw_new_mid, lenv)
        @old_mid = AST.create_node(raw_old_mid, lenv)
      end

      attr_reader :new_name, :old_name

      def subnodes = { new_name:, old_name: }

      def install0(genv)
        @new_mid.install(genv)
        @old_mid.install(genv)
        if @new_mid.is_a?(LIT) && @old_mid.is_a?(LIT)
          new_mid = @new_mid.lit
          old_mid = @old_mid.lit
          me = genv.resolve_method(@lenv.cref.cpath, false, new_mid)
          me.add_alias(self, old_mid)
          me.add_run_all_callsites(genv)
        end
        Source.new(genv.nil_type)
      end

      def uninstall0(genv)
        if @new_mid.is_a?(LIT) && @old_mid.is_a?(LIT)
          new_mid = @new_mid.lit
          me = genv.resolve_method(@lenv.cref.cpath, false, new_mid)
          me.remove_alias(self)
          me.add_run_all_callsites(genv)
        end
        super
      end

      def dump0(dumper)
        "alias #{ @new_mid.dump(dumper) } #{ @old_mid.dump(dumper) }"
      end
    end
  end
end