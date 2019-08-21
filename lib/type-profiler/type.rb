module TypeProfiler
  class Type # or Value?
    include Utils::StructuralEquality

    def initialize
      raise "cannot instanciate abstract type"
    end

    Builtin = {}

    def strip_local_info(env)
      strip_local_info_core(env, {})
    end

    def strip_local_info_core(env, visited)
      self
    end

    def consistent?(other)
      return true if other == Type::Any.new
      self == other
    end

    def each
      yield self
    end

    def sum(other)
      if other.is_a?(Type::Sum)
        Type::Sum.new(other.types + Utils::Set[self]).normalize
      else
        Type::Sum.new(Utils::Set[self, other]).normalize
      end
    end

    class Any < Type
      def initialize
      end

      def inspect
        "Type::Any"
      end

      def screen_name(scratch)
        "any"
      end

      def get_method(mid, scratch)
        nil
      end

      def consistent?(other)
        true
      end
    end

    class Sum < Type
      def initialize(tys)
        @types = tys # Set
      end

      def sum(other)
        if other.is_a?(Type::Sum)
          Type::Sum.new(@types + other.types).normalize
        else
          Type::Sum.new(@types + Utils::Set[other]).normalize
        end
      end

      def normalize
        if @types.size == 1
          @types.each {|ty| return ty }
        else
          self
        end
      end

      attr_reader :types

      def each(&blk)
        @types.each(&blk)
      end

      def inspect
        "Type::Sum{#{ @types.to_a.map {|ty| ty.inspect }.join(", ") }}"
      end

      def screen_name(scratch)
        @types.to_a.map do |ty|
          ty.screen_name(scratch)
        end.sort.join (" | ")
      end

      def strip_local_info_core(env, visited)
        Type::Sum.new(@types.map {|ty| ty.strip_local_info_core(env, visited) }).normalize
      end
    end

    class Class < Type
      def initialize(idx, name)
        @idx = idx
        @_name = name
      end

      attr_reader :idx

      def inspect
        if @_name
          "#{ @_name }@#{ @idx }"
        else
          "Class[#{ @idx }]"
        end
      end

      def screen_name(scratch)
        "#{ scratch.get_class_name(self) }.class"
      end

      def get_method(mid, scratch)
        scratch.get_singleton_method(self, mid)
      end
    end

    class Instance < Type
      def initialize(klass)
        @klass = klass
      end

      attr_reader :klass

      def inspect
        "I[#{ @klass.inspect }]"
      end

      def screen_name(scratch)
        scratch.get_class_name(@klass)
      end

      def get_method(mid, scratch)
        scratch.get_method(@klass, mid)
      end
    end

    class ISeq < Type
      def initialize(iseq)
        @iseq = iseq
      end

      attr_reader :iseq

      def inspect
        "Type::ISeq[#{ @iseq }]"
      end

      def screen_name(_scratch)
        raise NotImplementedError
      end
    end

    class ISeqProc < Type
      def initialize(iseq, ep, env, type)
        @iseq = iseq
        @ep = ep
        @env = env
        @type = type
      end

      attr_reader :iseq, :ep, :env

      def inspect
        "#<ISeqProc>"
      end

      def screen_name(_scratch)
        "??ISeqProc??"
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end
    end

    class TypedProc < Type
      def initialize(fargs, ret_ty, type)
        # XXX: need to receive blk_ty?
        # XXX: may refactor "arguments = arg_tys * blk_ty" out
        @fargs = fargs
        @ret_ty = ret_ty
        @type = type
      end

      attr_reader :fargs, :ret_ty
    end

    # local info
    class Literal < Type
      def initialize(lit, type)
        @lit = lit
        @type = type
      end

      attr_reader :lit, :type

      def inspect
        "Type::Literal[#{ @lit.inspect }, #{ @type.inspect }]"
      end

      def screen_name(scratch)
        @type.screen_name(scratch) + "<#{ @lit.inspect }>"
      end

      def strip_local_info_core(env, visited)
        @type
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end
    end

    class LocalArray < Type
      def initialize(id, base_type)
        @id = id
        @base_type = base_type
      end

      attr_reader :id, :base_type

      def inspect
        "Type::LocalArray[#{ @id }]"
      end

      def screen_name(scratch)
        #raise "LocalArray must not be included in signature"
        "LocalArray!"
      end

      def strip_local_info_core(env, visited)
        if visited[self]
          Type::Any.new
        else
          visited[self] = true
          elems = env.get_array_elem_types(@id)
          if elems
            elems = elems.strip_local_info_core(env, visited)
          else
            # TODO: currently out-of-scope array cannot be accessed
            elems = Array::Seq.new(Utils::Set[Type::Any.new])
          end
          Array.new(elems, @base_type)
        end
      end

      def get_method(mid, scratch)
        @base_type.get_method(mid, scratch)
      end
    end

    class Array < Type
      def initialize(elems, base_type)
        @elems = elems
        @base_type = base_type
        # XXX: need infinite recursion
      end

      attr_reader :elems, :base_type

      def inspect
        "Type::Array#{ @elems.inspect }"
        #@base_type.inspect
      end

      def screen_name(scratch)
        @elems.screen_name(scratch)
      end

      def strip_local_info_core(env, visited)
        self
      end

      def get_method(mid, scratch)
        raise
      end

      def self.tuple(elems, base_type = Type::Instance.new(Type::Builtin[:ary]))
        new(Tuple.new(*elems), base_type)
      end

      def self.seq(elems, base_type = Type::Instance.new(Type::Builtin[:ary]))
        new(Seq.new(elems), base_type)
      end

      def sum(other)
        raise NotImplementedError
      end

      class Seq
        include Utils::StructuralEquality

        def initialize(elems)
          raise if !elems.is_a?(Utils::Set)
          @elems = elems
        end

        attr_reader :elems

        def strip_local_info_core(env, visited)
          Seq.new(@elems.map {|ty| ty.strip_local_info_core(env, visited) })
        end

        def screen_name(scratch)
          s = []
          @elems.each {|ty| s << ty.screen_name(scratch) }
          "Array[" + s.sort.join(" | ") + "]"
        end

        def deploy_type(ep, env, id)
          elems = @elems.map do |ty|
            env, ty, id = env.deploy_type(ep, ty, id)
            ty
          end
          return env, Seq.new(elems), id
        end

        def types
          @elems
        end

        def [](idx)
          @elems
        end

        def update(_idx, ty)
          Seq.new(@elems + Utils::Set[ty])
        end

        def sum(other)
          Seq.new(@elems + other.types)
        end

        def each
          yield self
        end
      end

      class Tuple
        include Utils::StructuralEquality

        def initialize(*elems)
          @elems = elems
        end

        attr_reader :elems

        def strip_local_info_core(env, visited)
          elems = @elems.map do |elem|
            elem.map {|ty| ty.strip_local_info_core(env, visited) }
          end
          Tuple.new(*elems)
        end

        def pretty_print(q)
          q.group(6, "Tuple[", "]") do
            q.seplist(@elems) do |elem|
              q.pp elem
            end
          end
        end

        def screen_name(scratch)
          "[" + @elems.map do |elem|
            s = []
            elem.each {|ty| s << ty.screen_name(scratch) }
            s.join(" | ")
          end.join(", ") + "]"
        end

        def deploy_type(ep, env, id)
          elems = @elems.map do |elem|
            elem.map do |ty|
              env, ty, id = env.deploy_type(ep, ty, id)
              ty
            end
          end
          return env, Tuple.new(*elems), id
        end

        def types
          @elems.inject(&:+) || Utils::Set[Type::Instance.new(Type::Builtin[:nil])] # Is this okay?
        end

        def [](idx)
          @elems[idx] || Utils::Set[Type::Instance.new(Type::Builtin[:nil])] # HACK
        end

        def update(idx, ty)
          if idx && idx < @elems.size
            Tuple.new(*Utils.array_update(@elems, idx, Utils::Set[ty]))
          else
            Seq.new(types + Utils::Set[ty]) # converted to Seq
          end
        end

        def sum(other)
          Seq.new(types + other.types)
        end
      end
    end

    class Union
      include Utils::StructuralEquality

      def initialize(*tys)
        @types = tys.uniq
      end

      attr_reader :types

      def screen_name(scratch)
        @types.map do |ty|
          ty.screen_name(scratch)
        end.join(" | ")
      end

      def pretty_print(q)
        q.group(1, "{", "}") do
          q.seplist(@types, -> { q.breakable; q.text("|") }) do |ty|
            q.pp ty
          end
        end
      end
    end

    def self.guess_literal_type(obj)
      case obj
      when ::Symbol
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:sym]))
      when ::Integer
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:int]))
      when ::Class
        raise "unknown class: #{ obj.inspect }" if !obj.equal?(Object)
        Type::Builtin[:obj]
      when ::TrueClass, ::FalseClass
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:bool]))
      when ::Array
        ty = Type::Instance.new(Type::Builtin[:ary])
        Type::Array.tuple(obj.map {|arg| Utils::Set[guess_literal_type(arg)] }, ty)
      when ::String
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:str]))
      when ::Regexp
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:regexp]))
      when ::NilClass
        Type::Builtin[:nil]
      when ::Range
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:range]))
      else
        raise "unknown object: #{ obj.inspect }"
      end
    end
  end

  # Arguments for callee side
  class FormalArguments
    include Utils::StructuralEquality

    def initialize(lead_tys, opt_tys, rest_ty, post_tys, keyword_tys, blk_ty)
      @lead_tys = lead_tys
      @opt_tys = opt_tys
      @rest_ty = rest_ty
      @post_tys = post_tys
      @keyword_tys = keyword_tys
      @blk_ty = blk_ty
    end

    attr_reader :lead_tys, :opt_tys, :rest_ty, :post_tys, :keyword_tys, :blk_ty

    def consistent?(fargs)
      return false if @lead_tys.size != fargs.lead_tys.size
      return false unless @lead_tys.zip(fargs.lead_tys).all? {|ty1, ty2| ty1.consistent?(ty2) }
      return false if @opt_tys != fargs.opt_tys # ??
      if @rest_ty
        return false unless @rest_ty.consistent?(fargs.rest_ty)
      end
      if @post_tys
        return false if @post_tys.size != fargs.post_tys.size
        return false unless @post_tys.zip(fargs.post_tys).all? {|ty1, ty2| ty1.consistent?(ty2) }
      end
      return false if @keyword_tys != fargs.keyword_tys # ??
      # intentionally skip blk_ty
      true
    end

    def screen_name(scratch)
      fargs = @lead_tys.map {|ty| ty.screen_name(scratch) }
      if @opt_tys
        fargs += @opt_tys.map {|ty| ty.screen_name(scratch) }
      end
      # opt_tys
      if @rest_ty
        fargs << ("*" + @rest_ty.screen_name(scratch))
      end
      if @post_tys
        fargs += @post_tys.map {|ty| ty.screen_name(scratch) }
      end
      # keyword_tys
      # intentionally skip blk_ty
      fargs
    end
  end

  # Arguments from caller side
  class ActualArguments
    def initialize(lead_tys, rest_ty, blk_ty)
      @lead_tys = lead_tys
      @rest_ty = rest_ty
      @blk_ty = blk_ty
    end

    attr_reader :lead_tys, :rest_ty, :blk_ty

    def strip_local_info(caller_env)
      lead_tys = @lead_tys.map {|ty| ty.strip_local_info(caller_env) }
      rest_ty = @rest_ty.strip_local_info(caller_env) if @rest_ty
      ActualArguments.new(lead_tys, rest_ty, blk_ty)
    end

    def each_concrete_actual_arguments
      expand_sum_types(@lead_tys) do |lead_tys|
        if @rest_ty
          @rest_ty.each do |rest_ty|
            yield ActualArguments.new(lead_tys, rest_ty, @blk_ty)
          end
        else
          yield ActualArguments.new(lead_tys, rest_ty, @blk_ty)
        end
      end
    end

    def get_formal_arguments(fargs_format)
      lead_num = fargs_format[:lead_num] || 0
      post_num = fargs_format[:post_num] || 0
      post_start = fargs_format[:post_start]
      rest_start = fargs_format[:rest_start]
      block_start = fargs_format[:block_start]
      opt = fargs_format[:opt]

      start_pc = 0

      if @rest_ty
        raise
      else
        if lead_num + post_num > @lead_tys.size
          return "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
        end
        aargs = @lead_tys.dup
        lead_tys = aargs.shift(lead_num)
        post_tys = aargs.pop(post_num)
        if opt
          opt = opt[1..]
          opt_tys = []
          until aargs.empty? || opt.empty?
            opt_tys << aargs.shift
            start_pc = opt.shift
          end
        end
        if rest_start
          rest_ty = Type::Array.seq(Utils::Set[*aargs])
          aargs.clear
        end
        if !aargs.empty?
          return "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
        end
        return FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, nil, @blk_ty), start_pc
      end
    end

    private

    def expand_sum_types(sum_types, types = [], &blk)
      if sum_types.empty?
        yield types
      else
        rest = sum_types[1..]
        sum_types.first.each do |ty|
          expand_sum_types(rest, types + [ty], &blk)
        end
      end
    end

    def each_type(sum_types, types, &blk)
      if sum_types.empty?
        yield types
      else
        rest = sum_types[1..]
        sum_types.first.each do |ty|
          expand_sum_types(rest, types + [ty], &blk)
        end
      end
    end
  end

  class Signature
    include Utils::StructuralEquality

    def initialize(recv_ty, singleton, mid, fargs)
      @recv_ty = recv_ty
      @singleton = singleton
      @mid = mid
      @fargs = fargs
    end

    attr_reader :recv_ty, :singleton, :mid, :fargs

    def pretty_print(q)
      q.text "Signature["
      q.group do
        q.nest(2) do
          q.breakable
          q.pp @recv_ty
          q.text "##{ @mid }"
          q.text " ::"
          q.breakable
          q.group(2, "(", ")") do
            q.pp @fargs
            if @blk_ty
              q.text ","
              q.breakable
              q.text "&"
              q.pp @blk_ty
            end
          end
        end
        q.breakable
      end
      q.text "]"
    end
  end
end
