module TypeProfiler
  class MethodDef
    include Utils::StructuralEquality

    # TODO: state is no longer needed
    def do_send(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      if ctn
        do_send_core(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      else
        do_send_core(state, flags, recv, mid, aargs, ep, env, scratch) do |ret_ty, ep, env|
          nenv, ret_ty, = env.deploy_type(ep, ret_ty, 0)
          nenv = nenv.push(ret_ty)
          scratch.merge_env(ep.next, nenv)
        end
      end
    end
  end

  class ISeqMethodDef < MethodDef
    def initialize(iseq, cref, singleton)
      @iseq = iseq
      @cref = cref
      @singleton = singleton
    end

    def do_send_core(state, flags, recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      lead_num = @iseq.fargs[:lead_num] || 0
      post_start = @iseq.fargs[:post_start]
      rest_start = @iseq.fargs[:rest_start]
      block_start = @iseq.fargs[:block_start]

      recv = recv.strip_local_info(caller_env)
      aargs = aargs.strip_local_info(caller_env)

      aargs.each_formal_arguments(@iseq.fargs) do |fargs, start_pc|
        if fargs.is_a?(String)
          scratch.error(caller_ep, fargs)
          ctn[Type::Any.new, caller_ep, caller_env]
          next
        end

        fargs.each_concrete_formal_arguments do |fargs|
          ctx = Context.new(@iseq, @cref, Signature.new(recv, @singleton, mid, fargs)) # XXX: to support opts, rest, etc
          callee_ep = ExecutionPoint.new(ctx, start_pc, nil)

          locals = [Type::Instance.new(Type::Builtin[:nil])] * @iseq.locals.size
          nenv = Env.new(locals, [], {})
          id = 0
          fargs.lead_tys.each_with_index do |ty, i|
            nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
            nenv = nenv.local_update(i, ty)
          end
          if fargs.opt_tys
            fargs.opt_tys.each_with_index do |ty, i|
              nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
              nenv = nenv.local_update(lead_num + i, ty)
            end
          end
          if fargs.rest_ty
            nenv, rest_ty, id = nenv.deploy_type(callee_ep, fargs.rest_ty, id)
            nenv = nenv.local_update(rest_start, rest_ty)
          end
          if fargs.post_tys
            fargs.post_tys.each_with_index do |ty, i|
              nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
              nenv = nenv.local_update(post_start + i, ty)
            end
          end
          # keyword_tys
          nenv = nenv.local_update(block_start, fargs.blk_ty) if block_start

          # XXX: need to jump option argument
          scratch.merge_env(callee_ep, nenv)
          scratch.add_callsite!(callee_ep.ctx, caller_ep, caller_env, &ctn)
        end
      end
    end
  end

  class TypedMethodDef < MethodDef
    def initialize(sigs) # sigs: Array<[Signature, (return)Type]>
      @sigs = sigs
    end

    def do_send_core(state, _flags, recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      aargs, blk = aargs.lead_tys, aargs.blk_ty
      @sigs.each do |sig, ret_ty|
        recv = recv.strip_local_info(caller_env)
        # need to interpret args more correctly
        lead_tys = aargs.map {|aarg| aarg.strip_local_info(caller_env) }
        fargs = FormalArguments.new(lead_tys, nil, nil, nil, nil, blk) # aargs -> fargs
        dummy_ctx = Context.new(nil, nil, Signature.new(recv, nil, mid, fargs))
        dummy_ep = ExecutionPoint.new(dummy_ctx, -1, nil)
        dummy_env = Env.new([], [], {})
        # XXX: check blk type
        next unless fargs.consistent?(sig.fargs)
        scratch.add_callsite!(dummy_ctx, caller_ep, caller_env, &ctn)
        if sig.fargs.blk_ty.is_a?(Type::TypedProc)
          nfargs = sig.fargs.blk_ty.fargs
          blk_nil = Type::Instance.new(Type::Builtin[:nil]) # XXX: support block to block?
          naargs = ActualArguments.new(nfargs, nil, blk_nil)
          # XXX: do_invoke_block expects caller's env
          Scratch::Aux.do_invoke_block(false, blk, naargs, dummy_ep, dummy_env, scratch) do |_ret_ty, _ep, _env|
            # XXX: check the return type from the block
            # sig.blk_ty.ret_ty.eql?(_ret_ty) ???
            scratch.add_return_type!(dummy_ctx, ret_ty)
          end
          return
        end
        scratch.add_return_type!(dummy_ctx, ret_ty)
        return
      end

      scratch.error(caller_ep, "failed to resolve overload: #{ recv.screen_name(scratch) }##{ mid }")
      ctn[Type::Any.new, caller_ep, caller_env]
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
