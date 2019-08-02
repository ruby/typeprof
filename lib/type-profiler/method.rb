module TypeProfiler
  class MethodDef
    include Utils::StructuralEquality

    # TODO: state is no longer needed
    def do_send(state, flags, recv, mid, args, blk, ep, env, scratch, &ctn)
      if ctn
        do_send_core(state, flags, recv, mid, args, blk, ep, env, scratch, &ctn)
      else
        do_send_core(state, flags, recv, mid, args, blk, ep, env, scratch) do |ret_ty, ep, env|
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

    def do_send_core(state, flags, recv, mid, args, blk, caller_ep, caller_env, scratch, &ctn)
      recv = recv.strip_local_info(caller_env)
      args = args.map {|arg| arg.strip_local_info(caller_env) }
      expand_sum_types(args, []) do |args|
        # XXX: need to translate arguments to parameters
        argc = @iseq.args[:lead_num]
        if argc && argc != args.size
          scratch.error(caller_ep, "wrong number of arguments (given #{ args.size }, expected #{ argc })")
          ctn[Type::Any.new, caller_ep, caller_env]
        end

        case
        when blk.eql?(Type::Instance.new(Type::Builtin[:nil]))
        when blk.eql?(Type::Any.new)
        when blk.strip_local_info(caller_env).is_a?(Type::ISeqProc) # TODO: TypedProc
        else
          scratch.error(caller_ep, "wrong argument type #{ blk.screen_name(scratch) } (expected Proc)")
          blk = Type::Any.new
        end

        ctx = Context.new(@iseq, @cref, Signature.new(recv, @singleton, mid, args, blk))
        callee_ep = ExecutionPoint.new(ctx, 0, nil)

        locals = [Type::Instance.new(Type::Builtin[:nil])] * @iseq.locals.size
        locals[@iseq.args[:block_start]] = blk if @iseq.args[:block_start]
        nenv = Env.new(locals, [], {})
        id = 0
        args.each_with_index do |ty, i|
          nenv, ty, id = nenv.deploy_type(callee_ep, ty, id)
          nenv = nenv.local_update(i, ty)
        end

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

    def do_send_core(state, _flags, recv, mid, args, blk, caller_ep, caller_env, scratch, &ctn)
      @sigs.each do |sig, ret_ty|
        recv = recv.strip_local_info(caller_env)
        args = args.map {|arg| arg.strip_local_info(caller_env) }
        dummy_ctx = Context.new(nil, nil, Signature.new(recv, nil, mid, args, blk))
        dummy_ep = ExecutionPoint.new(dummy_ctx, -1, nil)
        dummy_env = Env.new([], [], {})
        # XXX: check blk type
        next if args.size != sig.arg_tys.size
        next unless args.zip(sig.arg_tys).all? {|ty1, ty2| ty1.consistent?(ty2) }
        scratch.add_callsite!(dummy_ctx, caller_ep, caller_env, &ctn)
        if sig.blk_ty.is_a?(Type::TypedProc)
          args = sig.blk_ty.arg_tys
          blk_nil = Type::Instance.new(Type::Builtin[:nil]) # XXX: support block to block?
          # XXX: do_invoke_block expects caller's env
          Scratch::Aux.do_invoke_block(false, blk, args, blk_nil, dummy_ep, dummy_env, scratch) do |_ret_ty, _ep, _env|
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

    def do_send_core(state, flags, recv, mid, args, blk, ep, env, scratch, &ctn)
      # XXX: ctn?
      @impl[state, flags, recv, mid, args, blk, ep, env, scratch, &ctn]
    end
  end
end
