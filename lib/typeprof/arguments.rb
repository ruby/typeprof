module TypeProf
  # Arguments for callee side
  class FormalArguments
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
  end

  # Arguments from caller side
  class ActualArguments
    def initialize(lead_tys, rest_ty, kw_tys, blk_ty)
      @lead_tys = lead_tys
      @rest_ty = rest_ty
      @kw_tys = kw_tys # kw_tys should be {:key1 => Type, :key2 => Type, ...} or {nil => Type}
      raise if !kw_tys.is_a?(::Hash)
      @blk_ty = blk_ty
      raise unless blk_ty
    end

    attr_reader :lead_tys, :rest_ty, :kw_tys, :blk_ty

    def globalize(caller_env, visited, depth)
      lead_tys = @lead_tys.map {|ty| ty.globalize(caller_env, visited, depth) }
      rest_ty = @rest_ty.globalize(caller_env, visited, depth) if @rest_ty
      kw_tys = @kw_tys.to_h do |key, ty|
        [key, ty.globalize(caller_env, visited, depth)]
      end
      ActualArguments.new(lead_tys, rest_ty, kw_tys, @blk_ty)
    end

    def limit_size(limit)
      self
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

      a_kw_tys = @kw_tys.dup
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

          if a_kw_tys.key?(key)
            ty = a_kw_tys.delete(key)
          else
            ty = a_kw_tys[nil] || Type.bot
          end
          if ty == Type.bot && req
            yield "no argument for required keywords"
            return
          end
          ty = ty.union(default_ty) if default_ty
          kw_tys << [req, key, ty]
        end
      end
      if kw_rest_acceptable
        if a_kw_tys.key?(nil)
          kw_rest_ty = Type.gen_hash {|h| h[Type.any] = a_kw_tys[nil] }
        else
          kw_rest_ty = Type.gen_hash do |h|
            a_kw_tys.each do |key, ty|
              sym = Type::Symbol.new(key, Type::Instance.new(Type::Builtin[:sym]))
              h[sym] = ty
            end
          end
        end
      end
      #if @kw_tys
      #  yield "passed a keyword to non-keyword method"
      #end

      (lower_bound .. upper_bound).each do |rest_len|
        aargs = @lead_tys + [rest_elem] * rest_len
        lead_tys = aargs.shift(lead_num)
        lead_tys << rest_elem until lead_tys.size == lead_num
        post_tys = aargs.pop(post_num)
        post_tys.unshift(rest_elem) until post_tys.size == post_num
        start_pcs = [0]
        if opt
          tmp_opt = opt[1..]
          opt_tys = []
          until aargs.empty? || tmp_opt.empty?
            opt_tys << aargs.shift
            start_pcs << tmp_opt.shift
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
        yield FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, kw_tys, kw_rest_ty, @blk_ty), start_pcs
      end
    end

    def consistent_with_method_signature?(msig, subst)
      aargs = @lead_tys.dup

      # aargs: lead_tys, rest_ty
      # msig: lead_tys, opt_tys, rest_ty, post_tys
      if @rest_ty
        lower_bound = [0, msig.lead_tys.size + msig.post_tys.size - aargs.size].max
        upper_bound = [0, lower_bound + msig.opt_tys.size].max
        (lower_bound..upper_bound).each do |n|
          tmp_aargs = ActualArguments.new(@lead_tys + [@rest_ty] * n, nil, @kw_tys, @blk_ty)
          if tmp_aargs.consistent_with_method_signature?(msig, subst) # XXX: wrong subst handling in the loop!
            return true
          end
        end
        return false
      end

      if msig.rest_ty
        return false if aargs.size < msig.lead_tys.size + msig.post_tys.size
        aargs.shift(msig.lead_tys.size).zip(msig.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.pop(msig.post_tys.size).zip(msig.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        msig.opt_tys.each do |farg|
          aarg = aargs.shift
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.each do |aarg|
          return false unless aarg.consistent?(msig.rest_ty, subst)
        end
      else
        return false if aargs.size < msig.lead_tys.size + msig.post_tys.size
        return false if aargs.size > msig.lead_tys.size + msig.post_tys.size + msig.opt_tys.size
        aargs.shift(msig.lead_tys.size).zip(msig.lead_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.pop(msig.post_tys.size).zip(msig.post_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
        aargs.zip(msig.opt_tys) do |aarg, farg|
          return false unless aarg.consistent?(farg, subst)
        end
      end
      # XXX: msig.keyword_tys

      case msig.blk_ty
      when Type::Proc
        return false if @blk_ty == Type.nil
      when Type.nil
        return false if @blk_ty != Type.nil
      when Type::Any
      else
        raise "unknown type of formal block signature"
      end
      true
    end

    def to_block_signature
      BlockSignature.new(@lead_tys, [], @rest_ty, @blk_ty)
    end

    def block_arguments(fargs_format)
      # XXX: Support @kw_tys
      argc = fargs_format[:lead_num] || 0
      lead_tys = @lead_tys.dup
      # actual argc == 1, not array, formal argc == 1: yield 42         => do |x|   : x=42
      # actual argc == 1,     array, formal argc == 1: yield [42,43,44] => do |x|   : x=[42,43,44]
      # actual argc >= 2,            formal argc == 1: yield 42,43,44   => do |x|   : x=42
      # actual argc == 1, not array, formal argc >= 2: yield 42         => do |x,y| : x,y=42,nil
      # actual argc == 1,     array, formal argc >= 2: yield [42,43,44] => do |x,y| : x,y=42,43
      # actual argc >= 2,            formal argc >= 2: yield 42,43,44   => do |x,y| : x,y=42,43
      if lead_tys.size >= 2 || argc == 0
        lead_tys.pop while argc < lead_tys.size
        lead_tys << Type.nil while argc > lead_tys.size
      else
        aarg_ty, = lead_tys
        if argc == 1
          lead_tys = [aarg_ty || Type.nil]
        else # actual argc == 1 && formal argc >= 2
          ary_elems = nil
          any_ty = nil
          case aarg_ty
          when Type::Union
            ary_elems = nil
            other_elems = nil
            aarg_ty.elems&.each do |(container_kind, base_type), elems|
              if container_kind == Type::Array
                ary_elems = ary_elems ? ary_elems.union(elems) : elems
              else
                other_elems = other_elems ? other_elems.union(elems) : elems
              end
            end
            aarg_ty = Type::Union.new(aarg_ty.types, other_elems)
            any_ty = Type.any if aarg_ty.types.include?(Type.any)
          when Type::Array
            ary_elems = aarg_ty.elems
            aarg_ty = nil
          when Type::Any
            any_ty = Type.any
          end
          lead_tys = [Type.bot] * argc
          lead_tys[0] = lead_tys[0].union(aarg_ty) if aarg_ty
          argc.times do |i|
            ty = lead_tys[i]
            ty = ty.union(ary_elems[i]) if ary_elems
            ty = ty.union(Type.any) if any_ty
            ty = ty.union(Type.nil) if i >= 1 && aarg_ty
            lead_tys[i] = ty
          end
        end
      end

      return lead_tys, @blk_ty
    end
  end
end
