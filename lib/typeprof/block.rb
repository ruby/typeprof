module TypeProf
  class Block
    include Utils::StructuralEquality
  end

  class ISeqBlock < Block
    def initialize(iseq, ep)
      @iseq = iseq
      @ep = ep
    end

    attr_reader :iseq, :ep

    def inspect
      "#<ISeqBlock: #{ ep.source_location }>"
    end

    def consistent?(other)
      if other.is_a?(ISeqBlock)
        self == other
      else
        true # XXX
      end
    end

    def substitute(_subst, _depth)
      self
    end

    def do_call(aargs, caller_ep, caller_env, scratch, replace_recv_ty:, &ctn)
      blk_env = scratch.return_envs[@ep]
      blk_env = blk_env.replace_recv_ty(replace_recv_ty) if replace_recv_ty
      arg_blk = aargs.blk_ty

      scratch.add_block_signature!(self, scratch.globalize_type(aargs, caller_env, caller_ep).to_block_signature)

      aargs_ = aargs.lead_tys.map {|aarg| scratch.globalize_type(aarg, caller_env, caller_ep) }
      # XXX: aargs.rest_tys, aargs.kw_tys, aargs.blk_tys
      argc = @iseq.fargs_format[:lead_num] || 0
      # actual argc == 1, not array, formal argc == 1: yield 42         => do |x|   : x=42
      # actual argc == 1,     array, formal argc == 1: yield [42,43,44] => do |x|   : x=[42,43,44]
      # actual argc >= 2,            formal argc == 1: yield 42,43,44   => do |x|   : x=42
      # actual argc == 1, not array, formal argc >= 2: yield 42         => do |x,y| : x,y=42,nil
      # actual argc == 1,     array, formal argc >= 2: yield [42,43,44] => do |x,y| : x,y=42,43
      # actual argc >= 2,            formal argc >= 2: yield 42,43,44   => do |x,y| : x,y=42,43
      if aargs_.size >= 2 || argc == 0
        aargs_.pop while argc < aargs_.size
        aargs_ << Type.nil while argc > aargs_.size
      else
        aarg_ty, = aargs_
        if argc == 1
          aargs_ = [aarg_ty || Type.nil]
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
          aargs_ = [Type.bot] * argc
          aargs_[0] = aargs_[0].union(aarg_ty) if aarg_ty
          argc.times do |i|
            ty = aargs_[i]
            ty = ty.union(ary_elems[i]) if ary_elems
            ty = ty.union(Type.any) if any_ty
            ty = ty.union(Type.nil) if i >= 1 && aarg_ty
            aargs_[i] = ty
          end
        end
      end
      locals = [Type.nil] * @iseq.locals.size
      locals[@iseq.fargs_format[:block_start]] = arg_blk if @iseq.fargs_format[:block_start]
      nctx = Context.new(@iseq, @ep.ctx.cref, nil)
      nep = ExecutionPoint.new(nctx, 0, @ep)
      nenv = Env.new(blk_env.static_env, locals, [], nil)
      alloc_site = AllocationSite.new(nep)
      aargs_.each_with_index do |ty, i|
        alloc_site2 = alloc_site.add_id(i)
        nenv, ty = scratch.localize_type(ty, nenv, nep, alloc_site2)
        nenv = nenv.local_update(i, ty)
      end

      scratch.merge_env(nep, nenv)

      scratch.add_block_to_ctx!(self, nep.ctx)
      scratch.add_callsite!(nep.ctx, caller_ep, caller_env, &ctn)
    end
  end

  class TypedBlock < Block
    def initialize(msig, ret_ty)
      @msig = msig
      @ret_ty = ret_ty
    end

    attr_reader :msig, :ret_ty

    def consistent?(other)
      if other.is_a?(ISeqBlock)
        raise "assert false"
      else
        self == other
      end
    end

    def substitute(subst, depth)
      msig = @msig.substitute(subst, depth)
      ret_ty = @ret_ty.substitute(subst, depth)
      TypedBlock.new(msig, ret_ty)
    end

    def do_call(aargs, caller_ep, caller_env, scratch, replace_recv_ty:, &ctn)
      subst = { Type::Var.new(:self) => caller_env.static_env.recv_ty } # XXX: support other type variables
      unless aargs.consistent_with_method_signature?(@msig, subst)
        scratch.warn(caller_ep, "The arguments is not compatibile to RBS block")
      end
      ctn[@ret_ty, caller_ep, caller_env]
    end
  end
end
