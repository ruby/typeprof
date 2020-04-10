module TypeProfiler
  class MethodDef
    include Utils::StructuralEquality

    def do_send(recv, mid, aargs, ep, env, scratch, &ctn)
      if ctn
        do_send_core(recv, mid, aargs, ep, env, scratch, &ctn)
      else
        do_send_core(recv, mid, aargs, ep, env, scratch) do |ret_ty, ep, env|
          nenv, ret_ty, = scratch.localize_type(ret_ty, env, ep)
          nenv = nenv.push(ret_ty)
          scratch.merge_env(ep.next, nenv)
        end
      end
    end
  end

  class ISeqMethodDef < MethodDef
    def initialize(iseq, cref)
      @iseq = iseq
      raise if iseq.nil?
      @cref = cref
    end

    def do_send_core(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      lead_num = @iseq.fargs_format[:lead_num] || 0
      post_start = @iseq.fargs_format[:post_start]
      rest_start = @iseq.fargs_format[:rest_start]
      kw_start = @iseq.fargs_format[:kwbits]
      kw_start -= @iseq.fargs_format[:keyword].size if kw_start
      block_start = @iseq.fargs_format[:block_start]

      recv = scratch.globalize_type(recv, caller_env, caller_ep)
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)

      aargs.each_formal_arguments(@iseq.fargs_format) do |fargs, start_pc|
        if fargs.is_a?(String)
          scratch.error(caller_ep, fargs)
          ctn[Type.any, caller_ep, caller_env]
          next
        end

        ctx = Context.new(@iseq, @cref, mid) # XXX: to support opts, rest, etc
        callee_ep = ExecutionPoint.new(ctx, start_pc, nil)

        locals = [Type.nil] * @iseq.locals.size
        nenv = Env.new(StaticEnv.new(recv, fargs.blk_ty, false), locals, [], Utils::HashWrapper.new({}))
        alloc_site = AllocationSite.new(callee_ep)
        idx = 0
        fargs.lead_tys.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          # nenv is top-level, so it is okay to call Type#localize directly
          nenv, ty = ty.localize(nenv, alloc_site2)
          nenv = nenv.local_update(i, ty)
        end
        if fargs.opt_tys
          fargs.opt_tys.each_with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(idx += 1)
            nenv, ty = ty.localize(nenv, alloc_site2)
            nenv = nenv.local_update(lead_num + i, ty)
          end
        end
        if fargs.rest_ty
          alloc_site2 = alloc_site.add_id(idx += 1)
          ty = Type::Array.new(Type::Array::Elements.new([], fargs.rest_ty), Type::Instance.new(Type::Builtin[:ary]))
          nenv, rest_ty = ty.localize(nenv, alloc_site2)
          nenv = nenv.local_update(rest_start, rest_ty)
        end
        if fargs.post_tys
          fargs.post_tys.each_with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(idx += 1)
            nenv, ty = ty.localize(nenv, alloc_site2)
            nenv = nenv.local_update(post_start + i, ty)
          end
        end
        if fargs.kw_tys
          fargs.kw_tys.each_with_index do |(_, _, ty), i|
            alloc_site2 = alloc_site.add_id(idx += 1)
            nenv, ty = ty.localize(nenv, alloc_site2)
            nenv = nenv.local_update(kw_start + i, ty)
          end
        end
        # kwrest
        nenv = nenv.local_update(block_start, fargs.blk_ty) if block_start

        scratch.merge_env(callee_ep, nenv)
        scratch.add_iseq_method_call!(self, callee_ep.ctx)
        scratch.add_callsite!(callee_ep.ctx, fargs, caller_ep, caller_env, &ctn)
      end
    end
  end

  class TypedMethodDef < MethodDef
    def initialize(sigs) # sigs: Array<[FormalArguments, (return)Type]>
      @sigs = sigs
    end

    def do_send_core(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      recv = scratch.globalize_type(recv, caller_env, caller_ep)
      found = false
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)
      @sigs.each do |fargs, ret_ty|
        # XXX: need to interpret args more correctly
        #pp [mid, aargs, fargs]
        # XXX: support self type in fargs
        next unless aargs.consistent_with_formal_arguments?(fargs)
        # XXX: support self type in container type like Array[Self]
        # XXX: support Union[Self, something]
        ret_ty = recv if ret_ty.is_a?(Type::Self)
        found = true
        if aargs.blk_ty.is_a?(Type::ISeqProc)
          dummy_ctx = Context.new(nil, nil, mid) # TODO: Unable to distinguish between A#foo and B#foo
          dummy_ep = ExecutionPoint.new(dummy_ctx, -1, nil)
          dummy_env = Env.new(StaticEnv.new(recv, fargs.blk_ty, false), [], [], Utils::HashWrapper.new({}))
          if fargs.blk_ty.is_a?(Type::TypedProc)
            scratch.add_callsite!(dummy_ctx, nil, caller_ep, caller_env, &ctn) # TODO: this add_callsite! and add_return_type! affects return value of all calls with block
            nfargs = fargs.blk_ty.fargs
            nfargs = nfargs.map do |nfarg|
              nfarg.is_a?(Type::Self) ? recv : nfarg # XXX
            end
            naargs = ActualArguments.new(nfargs, nil, nil, Type.nil) # XXX: support block to block?
            scratch.do_invoke_block(false, aargs.blk_ty, naargs, dummy_ep, dummy_env) do |_ret_ty, _ep, _env|
              # XXX: check the return type from the block
              # sig.blk_ty.ret_ty.eql?(_ret_ty) ???
              scratch.add_return_type!(dummy_ctx, ret_ty)
            end
            # scratch.add_return_type!(dummy_ctx, ret_ty) ?
            # This makes `def foo; 1.times { return "str" }; end` return Integer|String
          else
            # XXX: a block is passed to a method that does not accept block.
            # Should we call the passed block with any arguments?
            ctn[ret_ty, caller_ep, caller_env]
          end
        else
          ctn[ret_ty, caller_ep, caller_env]
        end
      end

      unless found
        scratch.error(caller_ep, "failed to resolve overload: #{ recv.screen_name(scratch) }##{ mid }")
        ctn[Type.any, caller_ep, caller_env]
      end
    end
  end

  class CustomMethodDef < MethodDef
    def initialize(impl)
      @impl = impl
    end

    def do_send_core(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      # XXX: ctn?
      scratch.merge_return_env(caller_ep) {|env| env ? env.merge(caller_env) : caller_env } # for Kernel#lambda
      @impl[recv, mid, aargs, caller_ep, caller_env, scratch, &ctn]
    end
  end
end
