module TypeProfiler
  class MethodDef
    include Utils::StructuralEquality

    # TODO: state is no longer needed
    def do_send(state, flags, recv, mid, aargs, blk, ep, env, scratch, &ctn)
      if ctn
        do_send_core(state, flags, recv, mid, aargs, blk, ep, env, scratch, &ctn)
      else
        do_send_core(state, flags, recv, mid, aargs, blk, ep, env, scratch) do |ret_ty, ep, env|
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

    def expand_sum_types(sum_types, types, &blk)
      if sum_types.empty?
        yield types
      else
        rest = sum_types[1..]
        sum_types.first.each do |ty|
          expand_sum_types(rest, types + [ty], &blk)
        end
      end
    end

    def do_send_core(state, flags, recv, mid, aargs, blk, caller_ep, caller_env, scratch, &ctn)
      recv = recv.strip_local_info(caller_env)
      aargs = aargs.map {|aarg| aarg.strip_local_info(caller_env) }
      # XXX: aargs may be splat, but not implemented yet...
      start_pc = 0
      expand_sum_types(aargs, []) do |aargs|
        # XXX: need to translate arguments to parameters
        lead_num = @iseq.fargs[:lead_num] || 0
        post_num = @iseq.fargs[:post_num] || 0
        post_start = @iseq.fargs[:post_start]
        rest_start = @iseq.fargs[:rest_start]
        block_start = @iseq.fargs[:block_start]
        opt = @iseq.fargs[:opt]

        # Currently assumes args is fixed-length
        if lead_num + post_num > aargs.size
          scratch.error(caller_ep, "wrong number of arguments (given #{ aargs.size }, expected #{ lead_num+post_num }..)")
          ctn[Type::Any.new, caller_ep, caller_env]
          return
        end
        aargs_orig = aargs
        aargs = aargs.dup
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
          scratch.error(caller_ep, "wrong number of arguments (given #{ aargs_orig.size }, expected #{ lead_num+post_num })")
          ctn[Type::Any.new, caller_ep, caller_env]
          return
        end

        case
        when blk.eql?(Type::Instance.new(Type::Builtin[:nil]))
        when blk.eql?(Type::Any.new)
        when blk.strip_local_info(caller_env).is_a?(Type::ISeqProc) # TODO: TypedProc
        else
          scratch.error(caller_ep, "wrong argument type #{ blk.screen_name(scratch) } (expected Proc)")
          blk = Type::Any.new
        end

        aargs = FormalArguments.new(lead_tys, opt_tys, rest_ty, post_tys, nil, blk)
        ctx = Context.new(@iseq, @cref, Signature.new(recv, @singleton, mid, aargs)) # XXX: to support opts, rest, etc
        callee_ep = ExecutionPoint.new(ctx, start_pc, nil)

        locals = [Type::Instance.new(Type::Builtin[:nil])] * @iseq.locals.size
        nenv = Env.new(locals, [], {})
        id = 0
        lead_tys.each_with_index do |ty, i|
          nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
          nenv = nenv.local_update(i, ty)
        end
        if opt_tys
          opt_tys.each_with_index do |ty, i|
            nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
            nenv = nenv.local_update(lead_num + i, ty)
          end
        end
        if rest_ty
          nenv, rest_ty, id = nenv.deploy_type(callee_ep, rest_ty, id)
          nenv = nenv.local_update(rest_start, rest_ty)
        end
        if post_tys
          post_tys.each_with_index do |ty, i|
            nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
            nenv = nenv.local_update(post_start + i, ty)
          end
        end
        # keyword_tys
        nenv = nenv.local_update(block_start, blk) if block_start

        # XXX: need to jump option argument
        scratch.merge_env(callee_ep, nenv)
        scratch.add_callsite!(callee_ep.ctx, caller_ep, caller_env, &ctn)
      end
    end
  end

  class TypedMethodDef < MethodDef
    def initialize(sigs) # sigs: Array<[Signature, (return)Type]>
      @sigs = sigs
    end

    def do_send_core(state, _flags, recv, mid, aargs, blk, caller_ep, caller_env, scratch, &ctn)
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
          fargs = sig.fargs.blk_ty.fargs
          blk_nil = Type::Instance.new(Type::Builtin[:nil]) # XXX: support block to block?
          # XXX: do_invoke_block expects caller's env
          Scratch::Aux.do_invoke_block(false, blk, fargs, blk_nil, dummy_ep, dummy_env, scratch) do |_ret_ty, _ep, _env|
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

    def do_send_core(state, flags, recv, mid, aargs, blk, ep, env, scratch, &ctn)
      # XXX: ctn?
      @impl[state, flags, recv, mid, aargs, blk, ep, env, scratch, &ctn]
    end
  end
end
