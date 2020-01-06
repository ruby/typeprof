module TypeProfiler
  class MethodDef
    include Utils::StructuralEquality

    # TODO: state is no longer needed
    def do_send(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      if ctn
        do_send_core(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      else
        do_send_core(state, flags, recv, mid, aargs, ep, env, scratch) do |ret_ty, ep, env|
          nenv, ret_ty, = ret_ty.deploy_local(env, ep)
          nenv = nenv.push(ret_ty)
          scratch.merge_env(ep.next, nenv)
        end
      end
    end
  end

  class ISeqMethodDef < MethodDef
    def initialize(iseq, cref, singleton)
      @iseq = iseq
      raise if iseq.nil?
      @cref = cref
      @singleton = singleton
    end

    def do_send_core(state, flags, recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      lead_num = @iseq.fargs_format[:lead_num] || 0
      post_start = @iseq.fargs_format[:post_start]
      rest_start = @iseq.fargs_format[:rest_start]
      block_start = @iseq.fargs_format[:block_start]

      recv = recv.strip_local_info(caller_env)
      aargs = aargs.strip_local_info(caller_env)

      aargs.each_formal_arguments(@iseq.fargs_format) do |fargs, start_pc|
        if fargs.is_a?(String)
          scratch.error(caller_ep, fargs)
          ctn[Type::Any.new, caller_ep, caller_env]
          next
        end

        ctx = Context.new(@iseq, @cref, Signature.new(@singleton, mid)) # XXX: to support opts, rest, etc
        callee_ep = ExecutionPoint.new(ctx, start_pc, nil)

        locals = [Type::Instance.new(Type::Builtin[:nil])] * @iseq.locals.size
        nenv = Env.new(recv, fargs.blk_ty, locals, [], {})
        alloc_site = AllocationSite.new(callee_ep)
        idx = 0
        fargs.lead_tys.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, ty = ty.deploy_local_core(nenv, alloc_site2)
          nenv = nenv.local_update(i, ty)
        end
        if fargs.opt_tys
          fargs.opt_tys.each_with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(idx += 1)
            nenv, ty = ty.deploy_local_core(nenv, alloc_site2)
            nenv = nenv.local_update(lead_num + i, ty)
          end
        end
        if fargs.rest_ty
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, rest_ty = fargs.rest_ty.deploy_local_core(nenv, alloc_site2)
          nenv = nenv.local_update(rest_start, rest_ty)
        end
        if fargs.post_tys
          fargs.post_tys.each_with_index do |ty, i|
            alloc_site2 = alloc_site.add_id(idx += 1)
            nenv, ty = ty.deploy_local_core(nenv, alloc_site2)
            nenv = nenv.local_update(post_start + i, ty)
          end
        end
        # keyword_tys
        nenv = nenv.local_update(block_start, fargs.blk_ty) if block_start

        # XXX: need to jump option argument
        scratch.merge_env(callee_ep, nenv)
        scratch.add_callsite!(callee_ep.ctx, fargs, caller_ep, caller_env, &ctn)
      end
    end
  end

  class TypedMethodDef < MethodDef
    def initialize(sigs) # sigs: Array<[Signature, FormalArguments, (return)Type]>
      @sigs = sigs
    end

    def do_send_core(state, _flags, recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      recv = recv.strip_local_info(caller_env)
      found = false
      @sigs.each do |sig, fargs, ret_ty|
        # need to interpret args more correctly
        #pp [aargs, fargs]
        next unless aargs.consistent_with_formal_arguments?(scratch, fargs)
        found = true
        dummy_ctx = Context.new(nil, nil, Signature.new(nil, mid))
        dummy_ep = ExecutionPoint.new(dummy_ctx, -1, nil)
        dummy_env = Env.new(recv, fargs.blk_ty, [], [], {})
        if fargs.blk_ty.is_a?(Type::TypedProc) && aargs.blk_ty.is_a?(Type::ISeqProc)
          scratch.add_callsite!(dummy_ctx, nil, caller_ep, caller_env, &ctn)
          nfargs = fargs.blk_ty.fargs
          blk_nil = Type::Instance.new(Type::Builtin[:nil]) # XXX: support block to block?
          naargs = ActualArguments.new(nfargs, nil, blk_nil)
          # XXX: do_invoke_block expects caller's env
          Scratch::Aux.do_invoke_block(false, aargs.blk_ty, naargs, dummy_ep, dummy_env, scratch) do |_ret_ty, _ep, _env|
            # XXX: check the return type from the block
            # sig.blk_ty.ret_ty.eql?(_ret_ty) ???
            scratch.add_return_type!(dummy_ctx, ret_ty)
          end
        end
        if fargs.blk_ty == Type::Instance.new(Type::Builtin[:nil]) && !aargs.blk_ty.is_a?(Type::ISeqProc)
          scratch.add_callsite!(dummy_ctx, nil, caller_ep, caller_env, &ctn)
          scratch.add_return_type!(dummy_ctx, ret_ty)
        end
      end

      unless found
        scratch.error(caller_ep, "failed to resolve overload: #{ recv.screen_name(scratch) }##{ mid }")
        ctn[Type::Any.new, caller_ep, caller_env]
      end
    end
  end

  class CustomMethodDef < MethodDef
    def initialize(impl)
      @impl = impl
    end

    def do_send_core(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      # XXX: ctn?
      @impl[state, flags, recv, mid, aargs, ep, env, scratch, &ctn]
    end
  end
end
