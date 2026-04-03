module TypeProf::Core
  class FormalArguments
    def initialize(req_positionals, opt_positionals, rest_positionals, post_positionals, req_keywords, opt_keywords, rest_keywords, block)
      @req_positionals = req_positionals
      @opt_positionals = opt_positionals
      @rest_positionals = rest_positionals
      @post_positionals = post_positionals
      @req_keywords = req_keywords
      @opt_keywords = opt_keywords
      @rest_keywords = rest_keywords
      @block = block
    end

    Empty = FormalArguments.new([], [], nil, [], [], [], nil, nil)

    attr_reader :req_positionals
    attr_reader :opt_positionals
    attr_reader :rest_positionals
    attr_reader :post_positionals
    attr_reader :req_keywords
    attr_reader :opt_keywords
    attr_reader :rest_keywords
    attr_reader :block
  end

  class ActualArguments
    def initialize(positionals, splat_flags, keywords, block)
      @positionals = positionals
      @splat_flags = splat_flags
      @keywords = keywords
      @block = block
    end

    attr_reader :positionals, :splat_flags, :keywords, :block

    def new_vertexes(genv, node)
      positionals = @positionals.map {|arg| arg.new_vertex(genv, node) }
      splat_flags = @splat_flags
      keywords = @keywords ? @keywords.new_vertex(genv, node) : nil
      block = @block ? @block.new_vertex(genv, node) : nil
      ActualArguments.new(positionals, splat_flags, keywords, block)
    end

    def with_keywords_as_last_positional_hash
      return self unless @keywords

      ActualArguments.new(
        @positionals + [@keywords],
        @splat_flags + [false],
        nil,
        @block
      )
    end

    def get_rest_args(genv, changes, start_rest, end_rest)
      vtxs = []

      start_rest.upto(end_rest - 1) do |i|
        a_arg = @positionals[i]
        if @splat_flags[i]
          a_arg.each_type do |ty|
            ty = ty.base_type(genv)
            if ty.is_a?(Type::Instance) && ty.mod == genv.mod_ary && ty.args[0]
              vtxs << changes.new_vertex(genv, self, ty.args[0])
            else
              "???"
            end
          end
        else
          vtxs << a_arg
        end
      end

      vtxs.uniq
    end

    def get_keyword_arg(genv, changes, name)
      vtx = Vertex.new(self)
      @keywords.each_type do |ty|
        case ty
        when Type::Hash
          changes.add_edge(genv, ty.get_value(name), vtx)
        when Type::Record
          field_vtx = ty.get_value(name)
          changes.add_edge(genv, field_vtx, vtx) if field_vtx
        when Type::Instance
          if ty.mod == genv.mod_hash
            changes.add_edge(genv, ty.args[1], vtx)
          end
        else
          # what to do?
        end
      end
      vtx
    end
  end

  class ForwardingArguments
    def initialize(req_positionals, opt_positionals, opt_positional_elems, rest_positionals, post_positionals, req_keyword_pairs, opt_keyword_pairs, rest_keywords, block)
      @req_positionals = req_positionals
      @opt_positionals = opt_positionals
      @opt_positional_elems = opt_positional_elems
      @rest_positionals = rest_positionals
      @post_positionals = post_positionals
      @req_keyword_pairs = req_keyword_pairs
      @opt_keyword_pairs = opt_keyword_pairs
      @rest_keywords = rest_keywords
      @block = block
    end

    attr_reader :block

    def to_actual_arguments(genv, changes, node)
      positionals = @req_positionals.dup
      splat_flags = ::Array.new(positionals.size, false)

      @opt_positionals.each do |arg|
        positionals << arg
        splat_flags << true
      end

      if @rest_positionals
        positionals << @rest_positionals
        splat_flags << true
      end

      @post_positionals.each do |arg|
        positionals << arg
        splat_flags << false
      end

      keywords = build_keyword_args(genv, changes, node)
      ActualArguments.new(positionals, splat_flags, keywords, @block)
    end

    def accept_actual_arguments(genv, changes, a_args)
      if a_args.splat_flags.any?
        start_rest = [a_args.splat_flags.index(true), @req_positionals.size + @opt_positionals.size].min
        end_rest = [a_args.splat_flags.rindex(true) + 1, a_args.positionals.size - @post_positionals.size].max
        rest_vtxs = a_args.get_rest_args(genv, changes, start_rest, end_rest)

        @req_positionals.each_with_index do |f_vtx, i|
          if i < start_rest
            changes.add_edge(genv, a_args.positionals[i], f_vtx)
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(genv, vtx, f_vtx)
            end
          end
        end

        @opt_positional_elems.each_with_index do |elem_vtx, i|
          i += @req_positionals.size
          if i < start_rest
            changes.add_edge(genv, a_args.positionals[i], elem_vtx)
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(genv, vtx, elem_vtx)
            end
          end
        end

        @post_positionals.each_with_index do |f_vtx, i|
          i += a_args.positionals.size - @post_positionals.size
          if end_rest <= i
            changes.add_edge(genv, a_args.positionals[i], f_vtx)
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(genv, vtx, f_vtx)
            end
          end
        end

      else
        @req_positionals.each_with_index do |f_vtx, i|
          changes.add_edge(genv, a_args.positionals[i], f_vtx)
        end

        @post_positionals.each_with_index do |f_vtx, i|
          i -= @post_positionals.size
          changes.add_edge(genv, a_args.positionals[i], f_vtx)
        end

        start_rest = @req_positionals.size
        end_rest = a_args.positionals.size - @post_positionals.size
        i = 0
        while i < @opt_positional_elems.size && start_rest < end_rest
          changes.add_edge(genv, a_args.positionals[start_rest], @opt_positional_elems[i])
          i += 1
          start_rest += 1
        end
      end

      changes.add_edge(genv, a_args.block, @block) if @block && a_args.block

      return unless a_args.keywords

      @req_keyword_pairs.each do |name, f_vtx|
        changes.add_edge(genv, a_args.get_keyword_arg(genv, changes, name), f_vtx)
      end

      @opt_keyword_pairs.each do |name, f_vtx|
        changes.add_edge(genv, a_args.get_keyword_arg(genv, changes, name), f_vtx)
      end

      if @rest_keywords
        named_keys = @req_keyword_pairs.map(&:first) + @opt_keyword_pairs.map(&:first)
        a_args.keywords.each_type do |kw_ty|
          case kw_ty
          when Type::Record
            rest_fields = kw_ty.fields.reject {|key, _| named_keys.include?(key) }
            base = kw_ty.base_type(genv)
            rest_record = Type::Record.new(genv, rest_fields, base)
            changes.add_edge(genv, Source.new(rest_record), @rest_keywords)
          when Type::Hash, Type::Instance
            changes.add_edge(genv, Source.new(kw_ty), @rest_keywords)
          end
        end
      end
    end

    private

    def build_keyword_args(genv, changes, node)
      return nil if @req_keyword_pairs.empty? && @opt_keyword_pairs.empty? && !@rest_keywords
      return @rest_keywords if @req_keyword_pairs.empty? && @opt_keyword_pairs.empty?

      unified_key = Vertex.new(node)
      unified_val = Vertex.new(node)
      literal_pairs = {}

      @req_keyword_pairs.each do |name, vtx|
        changes.add_edge(genv, Source.new(Type::Symbol.new(genv, name)), unified_key)
        changes.add_edge(genv, vtx, unified_val)
        literal_pairs[name] = vtx
      end

      @opt_keyword_pairs.each do |name, vtx|
        changes.add_edge(genv, Source.new(Type::Symbol.new(genv, name)), unified_key)
        changes.add_edge(genv, vtx, unified_val)
      end

      base_hash_type = genv.gen_hash_type(unified_key, unified_val)
      changes.add_hash_splat_box(genv, @rest_keywords, unified_key, unified_val) if @rest_keywords

      if literal_pairs.empty?
        Source.new(base_hash_type)
      else
        Source.new(Type::Record.new(genv, literal_pairs, base_hash_type))
      end
    end
  end

  class Block
    #: (AST::CallBaseNode, Vertex, Array[Vertex], Array[EscapeBox]) -> void
    def initialize(node, f_ary_arg, f_args, next_boxes)
      @node = node
      @f_ary_arg = f_ary_arg
      @f_args = f_args
      @next_boxes = next_boxes
    end

    attr_reader :node, :f_args, :next_boxes

    def accept_args(genv, changes, caller_positionals)
      if caller_positionals.size == 1 && @f_args.size >= 2
        changes.add_edge(genv, caller_positionals[0], @f_ary_arg)
      else
        caller_positionals.zip(@f_args) do |a_arg, f_arg|
          changes.add_edge(genv, a_arg, f_arg) if f_arg
        end
      end
    end

    def add_ret(genv, changes, ret)
      @next_boxes.each do |box|
        changes.add_edge(genv, box.a_ret, ret)
      end
    end
  end

  class RecordBlock
    def initialize(node)
      @node = node
      @used = false
      @f_args = []
      @ret = Vertex.new(node)
    end

    def get_f_arg(i)
      @f_args[i] ||= Vertex.new(@node)
    end

    attr_reader :node, :f_args, :ret, :used

    def accept_args(genv, changes, caller_positionals)
      @used = true
      caller_positionals.each_with_index do |a_arg, i|
        changes.add_edge(genv, a_arg.new_vertex(genv, @node), get_f_arg(i))
      end
    end

    def add_ret(genv, changes, ret)
      changes.add_edge(genv, ret, @ret)
    end
  end
end
