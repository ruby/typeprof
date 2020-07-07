module TypeProfiler
  class Type # or AbstractValue
    include Utils::StructuralEquality

    def initialize
      raise "cannot instanciate abstract type"
    end

    Builtin = {}

    def globalize(env, visited)
      self
    end

    def localize(env, _alloc_site)
      return env, self
    end

    def consistent?(other, subst)
      case other
      when Type::Any then true
      when Type::Var then other.add_subst!(self, subst)
      when Type::Union
        other.types.each do |ty2|
          return true if consistent?(ty2, subst)
        end
      else
        self == other
      end
    end

    def each_child
      yield self
    end

    def each_child_global
      yield self
    end

    def union(other)
      return self if self == other # fastpath

      ty1, ty2 = self, other

      ty1 = container_to_union(ty1)
      ty2 = container_to_union(ty2)

      if ty1.is_a?(Union) && ty2.is_a?(Union)
        ty = ty1.types.sum(ty2.types)
        array_elems = union_elems(ty1.array_elems, ty2.array_elems)
        hash_elems = union_elems(ty1.hash_elems, ty2.hash_elems)
        Type::Union.new(ty, array_elems, hash_elems).normalize
      else
        ty1, ty2 = ty2, ty1 if ty2.is_a?(Union)
        if ty1.is_a?(Union)
          Type::Union.new(ty1.types.add(ty2), ty1.array_elems, ty1.hash_elems).normalize
        else
          Type::Union.new(Utils::Set[ty1, ty2], nil, nil).normalize
        end
      end
    end

    private def container_to_union(ty)
      case ty
      when Type::Array
        Type::Union.new(Utils::Set[], ty.elems, nil)
      when Type::Hash
        Type::Union.new(Utils::Set[], nil, ty.elems)
      else
        ty
      end
    end

    private def union_elems(e1, e2)
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

    def substitute(subst)
      raise "cannot substitute abstract type: #{ self.class }"
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

      def consistent?(other, subst)
        # need to create a type assignment if other is Var
        other.add_subst!(self, subst) if other.is_a?(Type::Var)
        true
      end
    end

    class Union < Type
      def initialize(tys, ary_elems, hash_elems)
        raise unless tys.is_a?(Utils::Set)
        @types = tys # Set
        tys.each do |ty|
          raise if !ty.is_a?(Type)
          #raise if ty.is_a?(Type::Array)
          #raise if ty.is_a?(Type::Hash)
        end
        @array_elems = ary_elems # Type::Array::Elements
        @hash_elems = hash_elems # Type::Array::Elements
      end

      attr_reader :types, :array_elems, :hash_elems

      def normalize
        if @types.size == 1 && !@array_elems && !@hash_elems
          @types.each {|ty| return ty }
        elsif @types.size == 0
          if @array_elems && !@hash_elems
            Type::Array.new(@array_elems, Type::Instance.new(Type::Builtin[:ary]))
          elsif !@array_elems && @hash_elems
            Type::Hash.new(@hash_elems, Type::Instance.new(Type::Builtin[:hash]))
          else
            self
          end
        else
          self
        end
      end

      def each_child(&blk) # local
        @types.each(&blk)
        raise if @array_elems || @hash_elems
      end

      def each_child_global(&blk)
        @types.each(&blk)
        yield Type::Array.new(@array_elems, Type::Instance.new(Type::Builtin[:ary])) if @array_elems
        yield Type::Hash.new(@hash_elems, Type::Instance.new(Type::Builtin[:hash])) if @hash_elems
      end

      def inspect
        a = []
        a << "Type::Union{#{ @types.to_a.map {|ty| ty.inspect }.join(", ") }"
        a << ", #{ Type::Array.new(@array_elems, Type.any).inspect }" if @array_elems
        a << ", #{ Type::Hash.new(@hash_elems, Type.any).inspect }" if @hash_elems
        a << "}"
        a.join
      end

      def screen_name(scratch)
        types = @types.to_a
        if @array_elems
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          types << Type::Array.new(@array_elems, base_ty)
        end
        if @hash_elems
          base_ty = Type::Instance.new(Type::Builtin[:hash])
          types << Type::Hash.new(@hash_elems, base_ty)
        end
        if types.size == 0
          "bot"
        else
          types.to_a.map do |ty|
            ty.screen_name(scratch)
          end.sort.join (" | ")
        end
      end

      def globalize(env, visited)
        tys = Utils::Set[]
        array_elems = @array_elems&.globalize(env, visited)
        hash_elems = @hash_elems&.globalize(env, visited)
        @types.each do |ty|
          ty = ty.globalize(env, visited)
          case ty
          when Array
            array_elems = union_elems(array_elems, ty.elems)
          when Hash
            hash_elems = union_elems(hash_elems, ty.elems)
          else
            tys = tys.add(ty)
          end
        end
        Type::Union.new(tys, array_elems, hash_elems).normalize
      end

      def localize(env, alloc_site)
        tys = @types.map do |ty|
          alloc_site2 = alloc_site.add_id(ty)
          env, ty2 = ty.localize(env, alloc_site2)
          ty2
        end
        if @array_elems
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          ary_ty = Type::Array.new(@array_elems, base_ty)
          env, ary_ty = ary_ty.localize(env, alloc_site)
          tys = tys.add(ary_ty)
        end
        if @hash_elems
          base_ty = Type::Instance.new(Type::Builtin[:hash])
          hash_ty = Type::Hash.new(@hash_elems, base_ty)
          env, hash_ty = hash_ty.localize(env, alloc_site)
          tys = tys.add(hash_ty)
        end
        ty = Union.new(tys, nil, nil).normalize
        return env, ty
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          @types.each do |ty1|
            other.types.each do |ty2|
              return true if ty1.consistent?(ty2, subst)
            end
          end
          # TODO: array argument?
          return false
        else
          @types.each do |ty1|
            return true if ty1.consistent?(other, subst)
          end
          # TODO: array argument?
          return false
        end
      end

      def substitute(subst)
        types = @types.map {|ty| ty.substitute(subst) }
        array_elems = @array_elems&.substitute(subst)
        hash_elems = @hash_elems&.substitute(subst)
        Union.new(types, array_elems, hash_elems)
      end
    end

    def self.any
      @any ||= Any.new
    end

    def self.bot
      @bot ||= Union.new(Utils::Set[], nil, nil)
    end

    def self.bool
      @bool ||= Union.new(Utils::Set[
        Instance.new(Type::Builtin[:true]),
        Instance.new(Type::Builtin[:false])
      ], nil, nil)
    end

    def self.nil
      @nil ||= Instance.new(Type::Builtin[:nil])
    end

    def self.optional(ty)
      ty.union(Type.nil)
    end

    class Var < Type
      def initialize
      end

      def substitute(subst)
        subst[self] || self
      end

      def consistent?(other, subst)
        raise "should not be called"
      end

      def add_subst!(ty, subst)
        if subst[self]
          subst[self] = subst[self].union(ty)
        else
          subst[self] = ty
        end
        true
      end
    end

    class Class < Type # or Module
      def initialize(kind, idx, superclass, name)
        @kind = kind # :class | :module
        @idx = idx
        @superclass = superclass
        @_name = name
      end

      attr_reader :kind, :idx, :superclass

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
        scratch.get_method(self, true, mid)
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty|
            return true if consistent?(ty, subst)
          end
          return false
        when Type::Class
          ty = self
          loop do
            # ad-hoc
            return false if !ty || !other # module

            return true if ty.idx == other.idx
            return false if ty.idx == 0 # Object
            ty = ty.superclass
          end
        when Type::Instance
          return true if other.klass == Type::Builtin[:obj] || other.klass == Type::Builtin[:class] || other.klass == Type::Builtin[:module]
          return false
        else
          false
        end
      end

      def substitute(subst)
        self
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
        scratch.get_method(@klass, false, mid)
      end

      def consistent?(other, subst)
        case other
        when Type::Any then true
        when Type::Var then other.add_subst!(self, subst)
        when Type::Union
          other.types.each do |ty|
            return true if consistent?(ty, subst)
          end
          return false
        when Type::Instance
          @klass.consistent?(other.klass, subst)
        when Type::Class
          return true if @klass == Type::Builtin[:obj] || @klass == Type::Builtin[:class] || @klass == Type::Builtin[:module]
          return false
        else
          false
        end
      end

      def substitute(subst)
        Instance.new(@klass.substitute(subst))
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
      def initialize(iseq, ep, type)
        @iseq = iseq
        @ep = ep
        @type = type
      end

      attr_reader :iseq, :ep, :type

      def inspect
        "#<ISeqProc>"
      end

      def screen_name(scratch)
        "Proc[#{ scratch.proc_screen_name(self) }]" # TODO: use RBS syntax
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

      def consistent?(other, subst)
        case other
        when Var
          other.add_subst!(self, subst)
        when Symbol
          @sym == other.sym
        else
          @type.consistent?(other, subst)
        end
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

      def globalize(env, visited)
        @type
      end

      def get_method(mid, scratch)
        @type.get_method(mid, scratch)
      end

      def consistent?(other, subst)
        @type.consistent?(other, subst)
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

      def consistent?(other, subst)
        raise "Self type should not be checked for consistent?"
      end
    end

    class HashGenerator
      def initialize
        @map_tys = {}
      end

      attr_reader :map_tys

      def []=(k_ty, v_ty)
        k_ty.each_child_global do |k_ty|
          if @map_tys[k_ty]
            @map_tys[k_ty] = @map_tys[k_ty].union(v_ty)
          else
            @map_tys[k_ty] = v_ty
          end
        end
      end
    end

    def self.gen_hash
      hg = HashGenerator.new
      yield hg
      base_ty = Type::Instance.new(Type::Builtin[:hash])
      Type::Hash.new(Type::Hash::Elements.new(hg.map_tys), base_ty)
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
        return Type.any if obj < Exception
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
      when ::Hash
        Type.gen_hash do |h|
          obj.each do |k, v|
            k_ty = guess_literal_type(k).globalize(nil, {})
            v_ty = guess_literal_type(v)
            h[k_ty] = v_ty
          end
        end
      when ::String
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:str]))
      when ::Regexp
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:regexp]))
      when ::NilClass
        Type.nil
      when ::Range
        Type::Literal.new(obj, Type::Instance.new(Type::Builtin[:range]))
      else
        raise "unknown object: #{ obj.inspect }"
      end
    end

    def self.builtin_global_variable_type(var)
      case var
      when :$_, :$/, :$\, :$,, :$;
        Type.optional(Type::Instance.new(Type::Builtin[:str]))
      when :$0, :$PROGRAM_NAME
        Type::Instance.new(Type::Builtin[:str])
      when :$~
        Type.optional(Type::Instance.new(Type::Builtin[:matchdata]))
      when :$., :$$
        Type::Instance.new(Type::Builtin[:int])
      when :$?
        Type.optional(Type::Instance.new(Type::Builtin[:int]))
      when :$!
        Type.optional(Type::Instance.new(Type::Builtin[:exc]))
      when :$@
        str = Type::Instance.new(Type::Builtin[:str])
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        Type.optional(Type::Array.new(Type::Array::Elements.new([], str), base_ty))
      when :$*, :$:, :$LOAD_PATH, :$", :$LOADED_FEATURES
        str = Type::Instance.new(Type::Builtin[:str])
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        Type::Array.new(Type::Array::Elements.new([], str), base_ty)
      when :$<
        :ARGF
      when :$>
        :STDOUT
      when :$DEBUG
        Type.bool
      when :$FILENAME
        Type::Instance.new(Type::Builtin[:str])
      when :$stdin
        :STDIN
      when :$stdout
        :STDOUT
      when :$stderr
        :STDERR
      when :$VERBOSE
        Type.bool.union(Type.nil)
      else
        nil
      end
    end
  end

  # Arguments for callee side
  class FormalArguments
    include Utils::StructuralEquality

    def initialize(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, blk_ty)
      @lead_tys = lead_tys
      @opt_tys = opt_tys
      @rest_ty = rest_ty
      @post_tys = post_tys
      @kw_tys = kw_tys
      kw_tys.each {|a| raise if a.size != 3 } if kw_tys
      @kw_rest_ty = kw_rest_ty
      @blk_ty = blk_ty
    end

    attr_reader :lead_tys, :opt_tys, :rest_ty, :post_tys, :kw_tys, :kw_rest_ty, :blk_ty

    def consistent?(fargs, subst)
      warn "used?"
      return false if @lead_tys.size != fargs.lead_tys.size
      return false unless @lead_tys.zip(fargs.lead_tys).all? {|ty1, ty2| ty1.consistent?(ty2, subst) }
      return false if (@opt_tys || []) != (fargs.opt_tys || []) # ??
      if @rest_ty
        return false unless @rest_ty.consistent?(fargs.rest_ty, subst)
      end
      if @post_tys
        return false if @post_tys.size != fargs.post_tys.size
        return false unless @post_tys.zip(fargs.post_tys).all? {|ty1, ty2| ty1.consistent?(ty2, subst) }
      end
      return false if @kw_tys.size != fargs.kw_tys.size
      return false unless @kw_tys.zip(fargs.kw_tys).all? {|(_, ty1), (_, ty2)| ty1.consistent?(ty2, subst) }
      if @kw_rest_ty
        return false unless @kw_rest_ty.consistent?(fargs.kw_rest_ty, subst)
      end
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
      if @kw_tys
        @kw_tys.each do |req, sym, ty|
          opt = req ? "" : "?"
          fargs << "#{ opt }#{ sym }: #{ ty.screen_name(scratch) }"
        end
      end
      if @kw_rest_ty
        fargs << ("**" + @kw_rest_ty.screen_name(scratch))
      end
      # intentionally skip blk_ty
      fargs
    end

    def merge(other)
      raise if @lead_tys.size != other.lead_tys.size
      raise if @post_tys.size != other.post_tys.size
      if @kw_tys
        raise if @kw_tys.size != other.kw_tys.size
        @kw_tys.zip(other.kw_tys) {|(req1, k1, _), (req2, k2, _)| raise if req1 != req2 || k1 != k2 }
      else
        raise if other.kw_tys
      end
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
      kw_tys = @kw_tys.zip(other.kw_tys).map {|(req, k, ty1), (_, _, ty2)| [req, k, ty1.union(ty2)] } if @kw_tys
      if @kw_rest_ty || other.kw_rest_ty
        if @kw_rest_ty && other.kw_rest_ty
          kw_rest_ty = @kw_rest_ty.union(other.kw_rest_ty)
        else
          kw_rest_ty = @kw_rest_ty || other.kw_rest_ty
        end
      end
      blk_ty = @blk_ty.union(other.blk_ty) if @blk_ty
      FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, blk_ty)
    end
  end

  # Arguments from caller side
  class ActualArguments
    def initialize(lead_tys, rest_ty, kw_ty, blk_ty)
      @lead_tys = lead_tys
      @rest_ty = rest_ty
      @kw_ty = kw_ty
      @blk_ty = blk_ty
    end

    attr_reader :lead_tys, :rest_ty, :kw_ty, :blk_ty

    def merge(aargs)
      len = [@lead_tys.size, aargs.lead_tys.size].min
      lead_tys = @lead_tys[0, len].zip(aargs.lead_tys[0, len]).map do |ty1, ty2|
        ty1.union(ty2)
      end
      rest_ty = @rest_ty || Type.bot
      rest_ty = rest_ty.union(aargs.rest_ty) if aargs.rest_ty
      (@lead_tys[len..] + aargs.lead_tys[len..]).each do |ty|
        rest_ty = rest_ty.union(ty)
      end
      rest_ty = nil if rest_ty == Type.bot
      #kw_ty = @kw_ty.union(aargs.kw_ty) # TODO
      blk_ty = @blk_ty.union(aargs.blk_ty)
      ActualArguments.new(lead_tys, rest_ty, kw_ty, blk_ty)
    end

    def globalize(caller_env, visited)
      lead_tys = @lead_tys.map {|ty| ty.globalize(caller_env, visited) }
      rest_ty = @rest_ty.globalize(caller_env, visited) if @rest_ty
      kw_ty = @kw_ty.globalize(caller_env, visited) if @kw_ty
      ActualArguments.new(lead_tys, rest_ty, kw_ty, @blk_ty)
    end

    def each_formal_arguments(fargs_format)
      lead_num = fargs_format[:lead_num] || 0
      post_num = fargs_format[:post_num] || 0
      rest_acceptable = !!fargs_format[:rest_start]
      keyword = fargs_format[:keyword]
      kw_rest_acceptable = !!fargs_format[:kwrest]
      opt = fargs_format[:opt]
      #p fargs_format

      # TODO: expand tuples to normal arguments

      # check number of arguments
      if !@rest_ty && lead_num + post_num > @lead_tys.size
        # too less
        yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
        return
      end
      if !rest_acceptable
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
        upper_bound = lead_num + post_num - @lead_tys.size + (opt ? opt.size - 1 : 0) + (rest_acceptable ? 1 : 0)
        rest_elem = @rest_ty.is_a?(Type::Array) ? @rest_ty.elems.squash : Type.any
      else
        lower_bound = upper_bound = 0
      end

      if keyword
        kw_tys = []
        keyword.each do |kw|
          case
          when kw.is_a?(Symbol) # required keyword
            key = kw
            req = true
          when kw.size == 2 # optional keyword (default value is a literal)
            key, default_ty = *kw
            default_ty = Type.guess_literal_type(default_ty)
            default_ty = default_ty.type if default_ty.is_a?(Type::Literal)
            req = false
          else # optional keyword (default value is an expression)
            key, = kw
            req = false
          end

          sym = Type::Symbol.new(key, Type::Instance.new(Type::Builtin[:sym]))
          ty = Type.bot
          if @kw_ty.is_a?(Type::Hash)
            # XXX: consider Union
            ty = @kw_ty.elems[sym]
            # XXX: remove the key
          end
          if ty == Type.bot
            yield "no argument for required keywords"
            return
          end
          ty = ty.union(default_ty) if default_ty
          kw_tys << [req, key, ty]
        end
      end
      if kw_rest_acceptable
        kw_rest_ty = @kw_ty
      end
      #if @kw_ty
      #  yield "passed a keyword to non-keyword method"
      #end

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
        if rest_acceptable
          acc = aargs.inject {|acc, ty| acc.union(ty) }
          acc = acc ? acc.union(rest_elem) : rest_elem if rest_elem
          acc ||= Type.bot
          rest_ty = acc
          aargs.clear
        end
        if !aargs.empty?
          yield "wrong number of arguments (given #{ @lead_tys.size }, expected #{ lead_num + post_num })"
          return
        end
        yield FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, @blk_ty), start_pc
      end
    end

    def consistent_with_formal_arguments?(fargs, subst)
      aargs = @lead_tys.dup

      if @rest_ty
        lower_bound = fargs.lead_tys.size + fargs.post_tys.size - aargs.size
        upper_bound = lower_bound + fargs.opt_tys.size
        (lower_bound..upper_bound).each do |n|
          tmp_aargs = ActualArguments.new(@lead_tys + [@rest_ty] * n, nil, @kw_ty, @blk_ty)
          if tmp_aargs.consistent_with_formal_arguments?(fargs, subst)
            return true
          end
        end
        return false
      end

      if fargs.rest_ty
        return false if aargs.size < fargs.lead_tys.size + fargs.post_tys.size
        aargs.shift(fargs.lead_tys.size).zip(fargs.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.pop(fargs.post_tys.size).zip(fargs.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        fargs.opt_tys.each do |farg|
          aarg = aargs.shift
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.each do |aarg|
          return false unless aarg.consistent?(fargs.rest_ty, subst)
        end
      else
        return false if aargs.size < fargs.lead_tys.size + fargs.post_tys.size
        return false if aargs.size > fargs.lead_tys.size + fargs.post_tys.size + fargs.opt_tys.size
        aargs.shift(fargs.lead_tys.size).zip(fargs.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.pop(fargs.post_tys.size).zip(fargs.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.zip(fargs.opt_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
      end
      # XXX: fargs.keyword_tys

      case fargs.blk_ty
      when Type::TypedProc
        return false if @blk_ty == Type.nil
      when Type.nil
        return false if @blk_ty != Type.nil
      when Type::Any
      else
        raise "unknown typo of formal block signature"
      end
      true
    end

    def screen_name(scratch)
      aargs = @lead_tys.map {|ty| ty.screen_name(scratch) }
      if @rest_ty
        aargs << ("*" + @rest_ty.screen_name(scratch))
      end
      if @kw_ty
        aargs << ("**" + @kw_ty.screen_name(scratch)) # TODO: Hash notation -> keyword notation
      end
      s = "(#{ aargs.join(", ") })"
      s << " { #{ scratch.proc_screen_name(@blk_ty) } }" if @blk_ty != Type.nil
      s
    end
  end
end
