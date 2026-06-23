module TypeProf::Core
  class AST
    class ArrayPatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @requireds = raw_node.requireds.map {|raw_pat| AST.create_pattern_node(raw_pat, lenv) }
        @rest = !!raw_node.rest
        @rest_pattern = case raw_node.rest
                        when Prism::SplatNode
                          AST.create_pattern_node(raw_node.rest.expression, lenv) if raw_node.rest.expression
                        when Prism::ImplicitRestNode, nil
                          nil
                        else
                          raise
                        end

        @posts = raw_node.posts.map {|raw_pat| AST.create_pattern_node(raw_pat, lenv) }
      end

      attr_reader :requireds, :rest, :rest_pattern, :posts

      def attrs = { rest: }
      def subnodes = { requireds:, rest_pattern:, posts: }

      def install_pattern0(genv, subject)
        @requireds.each_with_index do |pat, i|
          pat.install_pattern(genv, @changes.add_splat_box(genv, subject, i).ret)
        end
        if @rest_pattern
          elem = @changes.add_splat_box(genv, subject).ret
          @rest_pattern.install_pattern(genv, Source.new(genv.gen_ary_type(elem)))
        end
        @posts.each do |pat|
          # TODO: precise indices for post elements (those after `*rest`)
          pat.install_pattern(genv, @changes.add_splat_box(genv, subject).ret)
        end
        subject
      end
    end

    class HashPatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @keys = raw_node.elements.map {|raw_assoc| raw_assoc.key.value.to_sym }
        @values = raw_node.elements.map {|raw_assoc| AST.create_pattern_node(raw_assoc.value, lenv) }
        @rest = !!raw_node.rest
        @rest_pattern = raw_node.rest && raw_node.rest.value ? AST.create_pattern_node(raw_node.rest.value, lenv) : nil
      end

      attr_reader :keys, :values, :rest, :rest_pattern

      def attrs = { keys:, rest: }
      def subnodes = { values:, rest_pattern: }

      def install_pattern0(genv, subject)
        # TODO: extract each key's value type from `subject` (captures stay untyped for now)
        @values.each do |pat|
          pat.install_pattern(genv, Vertex.new(self))
        end
        @rest_pattern.install_pattern(genv, Vertex.new(self)) if @rest_pattern
        subject
      end
    end

    class FindPatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @left = raw_node.left ? AST.create_pattern_node(raw_node.left.expression, lenv) : nil
        @requireds = raw_node.requireds.map {|raw_elem| AST.create_pattern_node(raw_elem, lenv) }
        @right = raw_node.right ? AST.create_pattern_node(raw_node.right.expression, lenv) : nil
      end

      attr_reader :left, :requireds, :right

      def subnodes = { left:, requireds:, right: }

      def install_pattern0(genv, subject)
        elem = @changes.add_splat_box(genv, subject).ret
        rest_ary = Source.new(genv.gen_ary_type(elem))
        @left.install_pattern(genv, rest_ary) if @left
        @requireds.each do |pat|
          pat.install_pattern(genv, elem)
        end
        @right.install_pattern(genv, rest_ary) if @right
        subject
      end
    end

    class AltPatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @left = AST.create_pattern_node(raw_node.left, lenv)
        @right = AST.create_pattern_node(raw_node.right, lenv)
      end

      attr_reader :left, :right

      def subnodes = { left:, right: }

      def install_pattern0(genv, subject)
        @left.install_pattern(genv, subject)
        @right.install_pattern(genv, subject)
        subject
      end
    end

    class CapturePatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @value = AST.create_pattern_node(raw_node.value, lenv)
        @target = AST.create_pattern_node(raw_node.target, lenv)
      end

      attr_reader :value, :target

      def subnodes = { value:, target: }

      def install_pattern0(genv, subject)
        @value.install_pattern(genv, subject)
        # For `Const => var`, narrow the capture by the class, as `when Const` does
        narrowed =
          if @value.is_a?(ConstantReadNode) && @value.static_ret
            filtered = subject.new_vertex(genv, self)
            IsAFilter.new(genv, self, filtered, false, @value.static_ret).next_vtx
          else
            subject
          end
        @target.install_pattern(genv, narrowed)
        subject
      end
    end

    class IfPatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @cond = AST.create_node(raw_node.predicate, lenv)
        raise if raw_node.statements.type != :statements_node
        raise if raw_node.statements.body.size != 1
        @body = AST.create_pattern_node(raw_node.statements.body[0], lenv)
        raise if raw_node.subsequent
      end

      attr_reader :cond, :body

      def subnodes = { cond:, body: }

      def install_pattern0(genv, subject)
        @cond.install(genv)
        @body.install_pattern(genv, subject)
        subject
      end
    end

    class PinnedPatternNode < Node
      def initialize(raw_node, lenv)
        super(raw_node, lenv)
        @expr = AST.create_node(raw_node.type == :pinned_variable_node ? raw_node.variable : raw_node.expression, lenv)
      end

      attr_reader :expr

      def subnodes = { expr: }

      def install0(genv)
        @expr.install(genv)
      end
    end
  end
end
