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
      lead_num = fargs_format[:lead_num] || 0
      post_num = fargs_format[:post_num] || 0
      post_index = fargs_format[:post_start]
      rest_index = fargs_format[:rest_start]
      keyword = fargs_format[:keyword]
      kw_index = fargs_format[:kwbits] - keyword.size if keyword
      kwrest_index = fargs_format[:kwrest]
      block_index = fargs_format[:block_start]
      opt = fargs_format[:opt] || [0]
      ambiguous_param0 = fargs_format[:ambiguous_param0]

      # The rule of passing arguments to block:
      #
      # Let A is actual arguments and F is formal arguments.
      # If F is NOT ambiguous_param0, and if length(A) == 1, and if A[0] is an Array,
      # then replace A with A[0]. And then, F[i] = A[i] for all 0 <= i < length(F).

      lead_tys = @lead_tys
      rest_ty = @rest_ty
      max_opt_count = 0

      all_bargs = []
      # Handling the special case
      if !ambiguous_param0
        if lead_tys.size == 1 && !rest_ty && @kw_tys.empty? # length(A) == 1
          ty = lead_tys[0]
          case ty
          when Type::Array
            lead_tys = ty.elems.lead_tys
            rest_ty = ty.elems.rest_ty
          when Type::Union
            other_elems = nil
            ty.elems&.each do |(container_kind, base_type), elems|
              if container_kind == Type::Array
                naargs = ActualArguments.new(elems.lead_tys, elems.rest_ty, {}, @blk_ty)
                bargs, start_pcs = naargs.block_arguments(fargs_format)
                all_bargs << bargs
                max_opt_count = [max_opt_count, start_pcs.size].max
              else
                other_elems = other_elems ? other_elems.union(elems) : elems
              end
            end
            lead_tys = [Type::Union.new(ty.types, other_elems)]
          end
        end
      end

      # Normal case: copy actual args to formal args
      if rest_ty
        rest_ty = rest_ty.union(Type.nil)

        if rest_index
          # yield a0, a1, a2, ...(rest_ty) -->
          #                do |l0, l1, o0=, o1=, *rest, p0, p1|
          # lead_ty argc == 0:  -   -   -    -      -    -   -
          # lead_ty argc == 1: a0   -   -    -      -    -   -
          # lead_ty argc == 2: a0  a1   -    -      -    -   -
          # lead_ty argc == 3: a0  a1   -    -      -   a2   -
          # lead_ty argc == 4: a0  a1   -    -      -   a2  a3
          # lead_ty argc == 5: a0  a1  a2    -      -   a3  a4
          # lead_ty argc == 6: a0  a1  a2   a3      -   a4  a5
          # lead_ty argc == 7: a0  a1  a2   a3    a4    a5  a6
          # lead_ty argc == 8: a0  a1  a2   a3    a4|a5 a6  a7
          #
          # l0   = a0
          # l1   = a1
          # o0   = a2
          # o1   = a3
          # rest = a4|a5|...|rest_ty (= cum_lead_tys[4])
          # p0   = a2|a3|...|rest_ty (= cum_lead_tys[2])
          # p1   = a3|a4|...|rest_ty (= cum_lead_tys[3])

          cum_lead_tys = []
          ty = rest_ty
          lead_tys.reverse_each do |ty0|
            cum_lead_tys.unshift(ty = ty.union(ty0))
          end

          # l1, l2, o1, o2
          bargs = []
          (lead_num + opt.size - 1).times {|i| bargs[i] = lead_tys[i] || rest_ty }
          opt_count = opt.size - 1

          # rest
          ty = cum_lead_tys[lead_num + opt.size - 1] || rest_ty
          bargs[rest_index] = Type::Array.new(Type::Array::Elements.new([], ty), Type::Instance.new(Type::Builtin[:ary]))

          # p0, p1
          post_num.times {|i| bargs[post_index + i] = cum_lead_tys[lead_tys.size + i] || rest_ty }
        else
          # yield a0, a1, a2, ...(rest_ty) -->
          #                do |l0, l1, o0=, o1=, p0, p1|
          # lead_ty argc == 0:  -   -   -    -    -   -
          # lead_ty argc == 1: a0   -   -    -    -   -
          # lead_ty argc == 2: a0  a1   -    -    -   -
          # lead_ty argc == 3: a0  a1   -    -   a2   -
          # lead_ty argc == 4: a0  a1   -    -   a2  a3
          # lead_ty argc == 5: a0  a1  a2    -   a3  a4
          # lead_ty argc == 5: a0  a1  a2   a3   a4  a5
          # lead_ty argc == 6: a0  a1  a2   a3   a4  a5 (a6: drop)
          #
          # l0 = a0
          # l1 = a1
          # o0 = a2
          # o1 = a3
          # p0 = a2|a3|a4
          # p1 = a3|a4|a5

          # l1, l2, o1, o2
          bargs = []
          (lead_num + opt.size - 1).times {|i| bargs[i] = lead_tys[i] || rest_ty }
          opt_count = opt.size - 1

          # p0, p1
          post_num.times do |i|
            candidates = lead_tys[lead_num, opt.size] || []
            candidates << rest_ty if candidates.size < opt.size
            bargs[post_index + i] = candidates.inject(&:union)
          end
        end
      else
        if rest_index
          # yield a0, a1, a2 -->
          #                do |l0, l1, o0=, o1=, *rest, p0, p1|
          # lead_ty argc == 0:  -   -   -    -      -    -   -
          # lead_ty argc == 1: a0   -   -    -      -    -   -
          # lead_ty argc == 2: a0  a1   -    -      -    -   -
          # lead_ty argc == 3: a0  a1   -    -      -   a2   -
          # lead_ty argc == 4: a0  a1   -    -      -   a2  a3
          # lead_ty argc == 5: a0  a1  a2    -      -   a3  a4
          # lead_ty argc == 6: a0  a1  a2   a3      -   a4  a5
          # lead_ty argc == 7: a0  a1  a2   a3    a4    a5  a6
          # lead_ty argc == 8: a0  a1  a2   a3    a4|a5 a6  a7
          #
          # l0   = a0
          # l1   = a1
          # o0   = a2
          # o1   = a3
          # rest = a4|a5|...|a[[4,len(a)-3].max]
          # p0   = a[[2,len(a)-2].max]
          # p1   = a[[3,len(a)-1].max]

          # l0, l1, o0, o1
          bargs = []
          (lead_num + opt.size - 1).times {|i| bargs[i] = lead_tys[i] || Type.nil }
          opt_count = [0, lead_tys.size - lead_num, opt.size - 1].sort[1]

          # rest
          rest_b = lead_num + opt.size - 1
          rest_e = [rest_b, lead_tys.size - post_num].max
          ty = (lead_tys[rest_b...rest_e] || []).inject(Type.bot, &:union)
          bargs[rest_index] = Type::Array.new(Type::Array::Elements.new([], ty), Type::Instance.new(Type::Builtin[:ary]))

          # p0, p1
          off = [lead_num, lead_tys.size - post_num].max
          post_num.times {|i| bargs[post_index + i] = lead_tys[off + i] || Type.nil }
        else
          # yield a0, a1, a2 -->
          #                do |l0, l1, o0=, o1=, p0, p1|
          # lead_ty argc == 0:  -   -   -    -    -   -
          # lead_ty argc == 1: a0   -   -    -    -   -
          # lead_ty argc == 2: a0  a1   -    -    -   -
          # lead_ty argc == 3: a0  a1   -    -   a2   -
          # lead_ty argc == 4: a0  a1   -    -   a2  a3
          # lead_ty argc == 5: a0  a1  a2    -   a3  a4
          # lead_ty argc == 6: a0  a1  a2   a3   a4  a5
          # lead_ty argc == 7: a0  a1  a2   a3   a4  a5 (a6: drop)

          # l0, l1, o0, o1
          bargs = []
          (lead_num + opt.size - 1).times {|i| bargs[i] = lead_tys[i] || Type.nil }
          opt_count = [0, lead_tys.size - lead_num, opt.size - 1].sort[1]

          # p0, p1
          post_num.times {|i| bargs[post_index + i] = lead_tys[lead_num + opt.size - 1 + i] || Type.nil }
        end
      end

      kw_tys = @kw_tys.dup
      if keyword
        keyword.each_with_index do |kw, i|
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

          if kw_tys.key?(key)
            ty = kw_tys.delete(key)
          else
            ty = kw_tys[nil] || Type.bot
          end

          if ty == Type.bot && req
            return "no argument for required keywords"
          end

          ty = ty.union(default_ty) if default_ty
          bargs[kw_index + i] = ty
        end
      end

      if kwrest_index
        if kw_tys.key?(nil)
          kw_rest_ty = Type.gen_hash {|h| h[Type.any] = kw_tys[nil] }
        else
          kw_rest_ty = Type.gen_hash do |h|
            kw_tys.each do |key, ty|
              sym = Type::Symbol.new(key, Type::Instance.new(Type::Builtin[:sym]))
              h[sym] = ty
            end
          end
        end
        bargs[kwrest_index] = kw_rest_ty
      else
        if !kw_tys.empty?
          return "unknown keyword: #{ kw_tys.keys.join(", ") }"
        end
      end

      if block_index
        bargs[block_index] = @blk_ty
      end

      bargs = bargs.map {|barg| barg || Type.nil }

      all_bargs << bargs

      # XXX: can we calculate the length of bargs statically?
      w = all_bargs.map {|bargs| bargs.size }.max
      bargs = all_bargs.map {|bargs| bargs + [Type.nil] * (w - bargs.size) }.transpose.map {|tys| tys.inject(&:union) }

      max_opt_count = [max_opt_count, opt_count].max
      start_pcs = opt[0..max_opt_count]

      return bargs, start_pcs
    end
  end
end
