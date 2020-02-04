module TypeProfiler
  class Type # or AbstractValue
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

    def deploy_local(env, ep)
      deploy_local_core(env, AllocationSite.new(ep))
    end

    def deploy_local_core(env, _alloc_site)
      return env, self
    end

    def consistent?(scratch, other)
      case other
      when Type::Any then true
      when Type::Union
        other.types.include?(self)
      else
        self == other
      end
    end

    def each_child
      yield self
    end

    def union(other)
      if self == other
        self
      elsif other.is_a?(Type::Union)
        if self.is_a?(Type::Array)
          Type::Union.new(other.types, self.elems).normalize
        else
          Type::Union.new(other.types.add(self), nil).normalize
        end
      elsif other.is_a?(Type::Array)
        if self.is_a?(Type::Array)
          Type::Union.new(Utils::Set[], self.elems.union(other.elems)).normalize
        else
          # TODO: What can we do about other.base_ty?
          Type::Union.new(Utils::Set[self], other.elems).normalize
        end
      else
        Type::Union.new(Utils::Set[self, other], nil).normalize
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

      def consistent?(scratch, other)
        true
      end
    end

    class Union < Type
      def initialize(tys, ary_elems)
        raise unless tys.is_a?(Utils::Set)
        @types = tys # Set
        tys.each do |ty|
          raise if ty.is_a?(Type::Array)
        end
        @array_elems = ary_elems # Type::Array::Elements
      end

      attr_reader :types, :array_elems

      def union_elems(e1, e2)
        if e1
          if e2
            e1.union(e2)
          else
            e1
          end
        else
          e2
        end
      end

      def union(other)
        if other.is_a?(Type::Union)
          Type::Union.new(@types.sum(other.types), union_elems(@array_elems, other.array_elems)).normalize
        elsif other.is_a?(Type::Array)
          Type::Union.new(@types, union_elems(@array_elems, other.elems)).normalize
        else
          Type::Union.new(@types.add(other), @array_elems).normalize
        end
      end

      def normalize
        if @types.size == 1 && !@array_elems
          @types.each {|ty| return ty }
        else
          self
        end
      end

      def each_child(&blk)
        @types.each(&blk)
        if @array_elems
          raise
        end
      end

      def inspect
        "Type::Union{#{ @types.to_a.map {|ty| ty.inspect }.join(", ") }, #{ Type::Array.new(@array_elems, Type.any).inspect }}"
      end

      def screen_name(scratch)
        types = @types.to_a
        if @array_elems
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          types << Type::Array.new(@array_elems, base_ty)
        end
        if types.size == 0
          "bot"
        else
          types.to_a.map do |ty|
            ty.screen_name(scratch)
          end.sort.join (" | ")
        end
      end

      def strip_local_info_core(env, visited)
        tys = Utils::Set[]
        array_elems = @array_elems&.strip_local_info_core(env, visited)
        @types.each do |ty|
          ty = ty.strip_local_info_core(env, visited)
          if ty.is_a?(Array)
            array_elems = union_elems(array_elems, ty.elems)
          else
            tys = tys.add(ty)
          end
        end
        Type::Union.new(tys, array_elems).normalize
      end

      def deploy_local_core(env, alloc_site)
        tys = @types.map do |ty|
          alloc_site2 = alloc_site.add_id(ty)
          env, ty2 = ty.deploy_local_core(env, alloc_site2)
          ty2
        end
        if @array_elems
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          ary_ty = Type::Array.new(@array_elems, base_ty)
          alloc_site2 = alloc_site.add_id(:ary)
          env, ary_ty = ary_ty.deploy_local_core(env, alloc_site2)
          tys = tys.add(ary_ty)
        end
        ty = Union.new(tys, nil)
        return env, ty
      end

      def consistent?(scratch, other)
        case other
        when Type::Any then true
        when Type::Union
          @types.each do |ty1|
            other.types.each do |ty2|
              return true if ty1.consistent?(scratch, ty2)
            end
          end
          # TODO: array argument?
          return false
        else
          @types.each do |ty1|
            return true if ty1.consistent?(scratch, other)
          end
          # TODO: array argument?
          return false
        end
      end
    end

    def self.any
      @any ||= Any.new
    end

    def self.bot
      @bot ||= Union.new(Utils::Set[], nil)
    end

    def self.bool
      @bool ||= Union.new(Utils::Set[
        Instance.new(Type::Builtin[:true]),
        Instance.new(Type::Builtin[:false])
      ], nil)
    end

    def self.nil
      @nil ||= Instance.new(Type::Builtin[:nil])
    end

    def self.optional(ty)
      ty.union(Type.nil)
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

      def consistent?(scratch, other)
        case other
        when Type::Any then true
        when Type::Union
          other.types.each_child do |ty|
            return true if consistent?(scratch, ty)
          end
          return false
        when Type::Class
          ty = self
          loop do
            return true if ty.idx == other.idx
            return false if ty.idx == 0 # Object
            ty = scratch.get_superclass(ty)
          end
        when Type::Instance
          return true if other.klass == Type::Builtin[:obj] || other.klass == Type::Builtin[:class] || other.klass == Type::Builtin[:module]
          return false
        else
          false
        end
      end
    end

    class Instance < Type
      def initialize(klass)
        raise unless klass
        raise if klass == Type.any
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

      def consistent?(scratch, other)
        case other
        when Type::Any then true
        when Type::Union
          other.types.each do |ty|
            return true if consistent?(scratch, ty)
          end
          return false
        when Type::Instance
          @klass.consistent?(scratch, other.klass)
        when Type::Class
          return true if @klass == Type::Builtin[:obj] || @klass == Type::Builtin[:class] || @klass == Type::Builtin[:module]
          return false
        else
          false
        end
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

    class Symbol < Type
      def initialize(sym, type)
        @sym = sym
        @type = type
      end

      attr_reader :sym, :type

      def inspect
        "Type::Symbol[#{ @sym ? @sym.inspect : "(dynamic symbol)" }, #{ @type.inspect }]"
      end

      def consistent?(scratch, other)
        @type.consistent?(scratch, other)
      end

      def screen_name(scratch)
        if @sym
          @sym.inspect
        else
          @type.screen_name(scratch)
        end
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end
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

      def consistent?(scratch, other)
        @type.consistent?(scratch, other)
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
          Type.any
        else
          visited[self] = true
          elems = env.get_array_elem_types(@id)
          if elems
            elems = elems.strip_local_info_core(env, visited)
          else
            # TODO: currently out-of-scope array cannot be accessed
            elems = Array::Elements.new([], Type.any)
          end
          Array.new(elems, @base_type)
        end
      end

      def get_method(mid, scratch)
        @base_type.get_method(mid, scratch)
      end

      def consistent?(scratch, other)
        raise "must not be used"
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

      def deploy_local_core(env, alloc_site)
        #alloc_site = alloc_site.add_id(:array)
        env, elems = @elems.deploy_local_core(env, alloc_site)
        env, ty = env.deploy_array_type(alloc_site, elems, @base_type)
      end

      def get_method(mid, scratch)
        raise
      end

      #def union(other)
      #  raise NotImplementedError
      #end

      # XXX
      #def consistent?(scratch, other)
      #  raise "must not be used"
      #end

      class Elements
        include Utils::StructuralEquality

        def initialize(lead_tys, rest_ty = Type.bot)
          raise unless lead_tys.all? {|ty| ty.is_a?(Type) }
          raise unless rest_ty.is_a?(Type)
          @lead_tys, @rest_ty = lead_tys, rest_ty
        end

        attr_reader :lead_tys, :rest_ty

        def strip_local_info_core(env, visited)
          lead_tys = []
          @lead_tys.each do |ty|
            lead_tys << ty.strip_local_info_core(env, visited)
          end
          rest_ty = @rest_ty&.strip_local_info_core(env, visited)
          Elements.new(lead_tys, rest_ty)
        end

        def deploy_local_core(env, alloc_site)
          lead_tys = @lead_tys.map.with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(i)
            env, ty = ty.deploy_local_core(env, alloc_site2)
            ty
          end
          alloc_site_rest = alloc_site.add_id(:rest)
          env, rest_ty = @rest_ty.deploy_local_core(env, alloc_site_rest)
          return env, Elements.new(lead_tys, rest_ty)
        end

        def screen_name(scratch)
          if ENV["TP_DUMP_RAW_ELEMENTS"] || @rest_ty == Type.bot
            s = @lead_tys.map do |ty|
              ty.screen_name(scratch)
            end
            s << "*" + @rest_ty.screen_name(scratch) if @rest_ty != Type.bot
            return "[#{ s.join(", ") }]"
          end

          "Array[#{ squash.screen_name(scratch) }]"
        end

        def pretty_print(q)
          q.group(9, "Elements[", "]") do
            q.seplist(@lead_tys + [@rest_ty]) do |elem|
              q.pp elem
            end
          end
        end

        def squash
          @lead_tys.inject(@rest_ty) {|ty1, ty2| ty1.union(ty2) } #.union(Type.nil) # is this needed?
        end

        def [](idx)
          if idx < @lead_tys.size
            @lead_tys[idx]
          elsif @rest_ty == Type.bot
            Type.nil
          else
            @rest_ty
          end
        end

        def update(idx, ty)
          if idx
            if idx < @lead_tys.size
              lead_tys = Utils.array_update(@lead_tys, idx, ty)
              Elements.new(lead_tys, @rest_ty)
            else
              rest_ty = @rest_ty.union(ty)
              Elements.new(@lead_tys, rest_ty)
            end
          else
            lead_tys = @lead_tys.map {|ty1| ty1.union(ty) }
            rest_ty = @rest_ty.union(ty)
            Elements.new(lead_tys, rest_ty)
          end
        end

        def append(ty)
          if @rest_ty == Type.bot
            if @lead_tys.size < 5 # XXX: should be configurable, or ...?
              lead_tys = @lead_tys + [ty]
              Elements.new(lead_tys, @rest_ty)
            else
              Elements.new(@lead_tys, ty)
            end
          else
            Elements.new(@lead_tys, @rest_ty.union(ty))
          end
        end

        def union(other)
          lead_count = [@lead_tys.size, other.lead_tys.size].min
          lead_tys = (0...lead_count).map do |i|
            @lead_tys[i].union(other.lead_tys[i])
          end

          rest_ty = @rest_ty.union(other.rest_ty)
          (@lead_tys[lead_count..-1] + other.lead_tys[lead_count..-1]).each do |ty|
            rest_ty = rest_ty.union(ty)
          end

          Elements.new(lead_tys, rest_ty)
        end

        def take_first(num)
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          if @lead_tys.size >= num
            lead_tys = @lead_tys[0, num]
            rest_ary_ty = Array.new(Elements.new(@lead_tys[num..-1], @rest_ty), base_ty)
            return lead_tys, rest_ary_ty
          else
            lead_tys = @lead_tys.dup
            until lead_tys.size == num
              # .union(Type.nil) is needed for `a, b, c = [42]` to assign nil to b and c
              lead_tys << @rest_ty.union(Type.nil)
            end
            rest_ary_ty = Array.new(Elements.new([], @rest_ty), base_ty)
            return lead_tys, rest_ary_ty
          end
        end

        def take_last(num)
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          if @rest_ty == Type.bot
            if @lead_tys.size >= num
              following_tys = @lead_tys[-num, num]
              rest_ary_ty = Array.new(Elements.new(@lead_tys[0...-num], Type.bot), base_ty)
              return rest_ary_ty, following_tys
            else
              following_tys = @lead_tys[-num, num] || []
              until following_tys.size == num
                following_tys.unshift(Type.nil)
              end
              rest_ary_ty = Array.new(Elements.new([], Type.bot), base_ty)
              return rest_ary_ty, following_tys
            end
          else
            lead_tys = @lead_tys.dup
            last_ty = rest_ty
            following_tys = []
            until following_tys.size == num
              last_ty = last_ty.union(lead_tys.pop) unless lead_tys.empty?
              following_tys.unshift(last_ty)
            end
            rest_ty = lead_tys.inject(last_ty) {|ty1, ty2| ty1.union(ty2) }
            rest_ary_ty = Array.new(Elements.new([], Type.bot), base_ty)
            return rest_ary_ty, following_tys
          end
        end
      end
    end

    class Self < Type
      # only for TypedMethod signature
      def initialize
      end

      def inspect
        "Type::Self"
      end

      def screen_name(scratch)
        "self"
      end

      def consistent?(scratch, other)
        raise "Self type should not be checked for consistent?"
      end
    end

    def self.guess_literal_type(obj)
      case obj
      when ::Symbol
        Type::Symbol.new(obj, Type::Instance.new(Type::Builtin[:sym]))
      when ::Integer
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:int]))
      when ::Float
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:float]))
      when ::Class
        raise "unknown class: #{ obj.inspect }" if !obj.equal?(Object)
        Type::Builtin[:obj]
      when ::TrueClass
        Type::Instance.new(Type::Builtin[:true])
      when ::FalseClass
        Type::Instance.new(Type::Builtin[:false])
      when ::Array
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        lead_tys = obj.map {|arg| guess_literal_type(arg) }
        Type::Array.new(Type::Array::Elements.new(lead_tys), base_ty)
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

    def consistent?(scratch, fargs)
      warn "used?"
      return false if @lead_tys.size != fargs.lead_tys.size
      return false unless @lead_tys.zip(fargs.lead_tys).all? {|ty1, ty2| ty1.consistent?(scratch, ty2) }
      return false if (@opt_tys || []) != (fargs.opt_tys || []) # ??
      if @rest_ty
        return false unless @rest_ty.consistent?(scratch, fargs.rest_ty)
      end
      if @post_tys
        return false if @post_tys.size != fargs.post_tys.size
        return false unless @post_tys.zip(fargs.post_tys).all? {|ty1, ty2| ty1.consistent?(scratch, ty2) }
      end
      return false if @keyword_tys != fargs.keyword_tys # ??
      # intentionally skip blk_ty
      true
    end

    def screen_name(scratch)
      fargs = @lead_tys.map {|ty| ty.screen_name(scratch) }
      if @opt_tys
        fargs += @opt_tys.map {|ty| "?" + ty.screen_name(scratch) }
      end
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

    def merge(other)
      raise if @lead_tys.size != other.lead_tys.size
      #raise if @post_tys.size != other.post_tys.size
      #raise if @keyword_tys.size != other.keyword_tys.size
      lead_tys = @lead_tys.zip(other.lead_tys).map {|ty1, ty2| ty1.union(ty2) }
      if @opt_tys || other.opt_tys
        opt_tys = []
        [@opt_tys.size, other.opt_tys.size].max.times do |i|
          ty1 = @opt_tys[i]
          ty2 = other.opt_tys[i]
          ty = ty1 ? ty2 ? ty1.union(ty2) : ty1 : ty2
          opt_tys << ty
        end
      end
      if @rest_ty || other.rest_ty
        if @rest_ty && other.rest_ty
          rest_ty = @rest_ty.union(other.rest_ty)
        else
          rest_ty = @rest_ty || other.rest_ty
        end
      end
      post_tys = @post_tys.zip(other.post_tys).map {|ty1, ty2| ty1.union(ty2) }
      blk_ty = @blk_ty.union(other.blk_ty) if @blk_ty
      FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, nil, blk_ty)
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

    def each_formal_arguments(fargs_format)
      lead_num = fargs_format[:lead_num] || 0
      post_num = fargs_format[:post_num] || 0
      post_start = fargs_format[:post_start]
      rest_start = fargs_format[:rest_start]
      block_start = fargs_format[:block_start]
      opt = fargs_format[:opt]

      # TODO: expand tuples to normal arguments

      # check number of arguments
      if !@rest_ty && lead_num + post_num > @lead_tys.size
        # too less
        yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
        return
      end
      if !rest_start
        # too many
        if opt
          if lead_num + post_num + opt.size - 1 < @lead_tys.size
            yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num }..#{ lead_num + post_num + opt.size - 1})"
            return
          end
        else
          if lead_num + post_num < @lead_tys.size
            yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
            return
          end
        end
      end

      if @rest_ty
        lower_bound = [lead_num + post_num - @lead_tys.size, 0].max
        upper_bound = lead_num + post_num - @lead_tys.size + (opt ? opt.size - 1 : 0) + (rest_start ? 1 : 0)
        rest_elem = @rest_ty.eql?(Type.any) ? Type.any : @rest_ty.elems.squash
      else
        lower_bound = upper_bound = 0
      end

      (lower_bound .. upper_bound).each do |rest_len|
        aargs = @lead_tys + [rest_elem] * rest_len
        lead_tys = aargs.shift(lead_num)
        lead_tys << rest_elem until lead_tys.size == lead_num
        post_tys = aargs.pop(post_num)
        post_tys.unshift(rest_elem) until post_tys.size == post_num
        start_pc = 0
        if opt
          tmp_opt = opt[1..]
          opt_tys = []
          until aargs.empty? || tmp_opt.empty?
            opt_tys << aargs.shift
            start_pc = tmp_opt.shift
          end
        end
        if rest_start
          acc = aargs.inject {|acc, ty| acc.union(ty) }
          acc = acc ? acc.union(rest_elem) : rest_elem if rest_elem
          rest_ty = acc
          #elem = acc.is_a?(Type::Union) ? acc.types : acc ? Utils::Set[acc] : Utils::Set[]
          #rest_ty = Type::Array.seq(elem)
          aargs.clear
        end
        if !aargs.empty?
          yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
          return
        end
        yield FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, nil, @blk_ty), start_pc
      end
    end

    def consistent_with_formal_arguments?(scratch, fargs)
      #@lead_tys = lead_tys
      #@rest_ty = rest_ty
      #@blk_ty = blk_ty
      aargs = @lead_tys.dup
      if @rest_ty
        raise NotImplementedError
      else
        return false if aargs.size < fargs.lead_tys.size + fargs.post_tys.size
        return false if aargs.size > fargs.lead_tys.size + fargs.post_tys.size + fargs.opt_tys.size
        aargs.shift(fargs.lead_tys.size).zip(fargs.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(scratch, farg)
        end
        aargs.pop(fargs.post_tys.size).zip(fargs.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(scratch, farg)
        end
        aargs.zip(fargs.opt_tys) do |aarg, farg|
          return false unless aarg.consistent?(scratch, farg)
        end
      end
      # XXX: fargs.keyword_tys
      true
    end
  end

  class AllocationSite
    include Utils::StructuralEquality

    def initialize(val, parent = nil)
      raise if !val.is_a?(Utils::StructuralEquality) && !val.is_a?(Integer) && !val.is_a?(Symbol)
      @val = val
      @parent = parent
    end

    attr_reader :val, :parent

    def add_id(val)
      AllocationSite.new(val, self)
    end
  end
end
