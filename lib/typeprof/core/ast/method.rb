module TypeProf::Core
  class AST
    def self.get_rbs_comment_before(pos)
      tokens = Fiber[:tokens]
      i = tokens.bsearch_index {|_type, _str, code_range| pos <= code_range.first }
      if i
        comments = []
        while i > 0
          i -= 1
          type, str, = tokens[i]
          case type
          when :tSP
            # ignore
          when :tCOMMENT
            break unless str.start_with?("#:")
            comments << str[2..]
          else
            break
          end
        end
        RBS::Parser.parse_method_type(comments.reverse.join)
      end
    end

    class DefNode < Node
      def initialize(raw_node, lenv, singleton, mid, raw_scope)
        super(raw_node, lenv)

        # @rbs = AST.get_rbs_comment_before(code_range.first)

        @singleton = singleton
        @mid = mid

        raise unless raw_scope.type == :SCOPE
        @tbl, raw_args, raw_body = raw_scope.children

        # TODO: default expression for optional args
        @args = raw_args.children
        @args[2] = nil # temporarily delete OPT_ARG

        ncref = CRef.new(lenv.cref.cpath, @singleton, lenv.cref)
        locals = {}
        @tbl.each {|var| locals[var] = Source.new(Type.nil) }
        locals[:"*self"] = Source.new(ncref.get_self)
        locals[:"*ret"] = Vertex.new("method_ret", self)
        nlenv = LocalEnv.new(@lenv.path, ncref, locals)
        if raw_body
          @body = AST.create_node(raw_body, nlenv)
        else
          @body = NilNode.new(code_range, nlenv)
        end

        @args_code_ranges = []
        @args[0].times do |i|
          pos = TypeProf::CodePosition.new(raw_node.first_lineno, raw_node.first_column)
          @args_code_ranges << AST.find_sym_code_range(pos, @tbl[i])
        end

        @reused = false
      end

      attr_reader :singleton, :mid, :tbl, :args, :body

      def subnodes = @reused ? {} : { body: }
      def attrs = { singleton:, mid:, tbl:, args: }

      attr_accessor :reused

      def define0(genv)
        if @prev_node
          reuse
          @prev_node.reused = true
        else
          super
        end
      end

      def install0(genv)
        unless @prev_node
          # TODO: ユーザ定義 RBS があるときは検証する
          f_args = []
          block = nil
          if @args
            @args[0].times do |i|
              f_args << @body.lenv.new_var(@tbl[i], self)
            end
            # &block
            block = @body.lenv.new_var(:"*given_block", self)
            @body.lenv.set_var(@args[9], block) if @args[9]
          end
          ret = @body.lenv.get_var(:"*ret")
          if @body
            body_ret = @body.install(genv)
          else
            body_ret = Source.new(Type.nil)
          end
          body_ret.add_edge(genv, ret)
          mdef = MethodDef.new(self, f_args, block, ret)
          add_method_def(genv, @lenv.cref.cpath, @singleton, @mid, mdef)
        end
        Source.new(Type::Symbol.new(@mid))
      end

      def hover(pos)
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
          genv.resolve_method(@lenv.cref.cpath, false, new_mid).add_alias(self, old_mid)
          genv.resolve_cpath(@lenv.cref.cpath).add_run_all_callsites(genv, false, new_mid)
        end
        Source.new(Type.nil)
      end

      def uninstall0(genv)
        if @new_mid.is_a?(LIT) && @old_mid.is_a?(LIT)
          new_mid = @new_mid.lit
          genv.resolve_method(@lenv.cref.cpath, false, new_mid).remove_alias(self)
          genv.resolve_cpath(@lenv.cref.cpath).add_run_all_callsites(genv, false, new_mid)
        end
        super
      end

      def dump0(dumper)
        "alias #{ @new_mid.dump(dumper) } #{ @old_mid.dump(dumper) }"
      end
    end
  end
end