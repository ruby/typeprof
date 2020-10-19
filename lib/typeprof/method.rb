module TypeProf
  class MethodDef
    include Utils::StructuralEquality
  end

  class ISeqMethodDef < MethodDef
    def initialize(iseq, cref)
      @iseq = iseq
      raise if iseq.nil?
      @cref = cref
    end

    def do_send(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      recv = scratch.globalize_type(recv, caller_env, caller_ep)
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)

      aargs.each_formal_arguments(@iseq.fargs_format) do |fargs, start_pc|
        if fargs.is_a?(String)
          scratch.error(caller_ep, fargs)
          ctn[Type.any, caller_ep, caller_env]
          next
        end

        callee_ep = do_send_core(fargs, start_pc, recv, mid, scratch)

        scratch.add_iseq_method_call!(self, callee_ep.ctx)
        scratch.add_callsite!(callee_ep.ctx, fargs, caller_ep, caller_env, &ctn)
      end
    end

    def do_send_core(fargs, start_pc, recv, mid, scratch)
      lead_num = @iseq.fargs_format[:lead_num] || 0
      post_start = @iseq.fargs_format[:post_start]
      rest_start = @iseq.fargs_format[:rest_start]
      kw_start = @iseq.fargs_format[:kwbits]
      kw_start -= @iseq.fargs_format[:keyword].size if kw_start
      block_start = @iseq.fargs_format[:block_start]

      # XXX: need to check .rbs fargs and .rb fargs

      ctx = Context.new(@iseq, @cref, mid) # XXX: to support opts, rest, etc
      callee_ep = ExecutionPoint.new(ctx, start_pc, nil)

      locals = [Type.nil] * @iseq.locals.size
      nenv = Env.new(StaticEnv.new(recv, fargs.blk_ty, false), locals, [], Utils::HashWrapper.new({}))
      alloc_site = AllocationSite.new(callee_ep)
      idx = 0
      fargs.lead_tys.each_with_index do |ty, i|
        alloc_site2 = alloc_site.add_id(idx += 1)
        # nenv is top-level, so it is okay to call Type#localize directly
        nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
        nenv = nenv.local_update(i, ty)
      end
      if fargs.opt_tys
        fargs.opt_tys.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
          nenv = nenv.local_update(lead_num + i, ty)
        end
      end
      if fargs.rest_ty
        alloc_site2 = alloc_site.add_id(idx += 1)
        ty = Type::Array.new(Type::Array::Elements.new([], fargs.rest_ty), Type::Instance.new(Type::Builtin[:ary]))
        nenv, rest_ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
        nenv = nenv.local_update(rest_start, rest_ty)
      end
      if fargs.post_tys
        fargs.post_tys.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
          nenv = nenv.local_update(post_start + i, ty)
        end
      end
      if fargs.kw_tys
        fargs.kw_tys.each_with_index do |(_, _, ty), i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
          nenv = nenv.local_update(kw_start + i, ty)
        end
      end
      # kwrest
      nenv = nenv.local_update(block_start, fargs.blk_ty) if block_start

      scratch.merge_env(callee_ep, nenv)

      callee_ep
    end

    def do_check_send_core(fargs, recv, mid, ep, scratch)
      lead_num = @iseq.fargs_format[:lead_num] || 0
      post_num = @iseq.fargs_format[:post_num] || 0
      rest_start = @iseq.fargs_format[:rest_start]
      opt = @iseq.fargs_format[:opt] || [0]

      # TODO: check keywords
      if rest_start
        # almost ok
      else
        if fargs.lead_tys.size + fargs.post_tys.size < lead_num + post_num
          scratch.error(ep, "RBS says that the arity may be %d, but the method definition requires at least %d arguments" % [fargs.lead_tys.size + fargs.post_tys.size, lead_num + post_num])
          return
        end
        if fargs.lead_tys.size + fargs.opt_tys.size + fargs.post_tys.size > lead_num + opt.size - 1 + post_num
          scratch.error(ep, "RBS says that the arity may be %d, but the method definition requires at most %d arguments" % [fargs.lead_tys.size + fargs.opt_tys.size + fargs.post_tys.size, lead_num + opt.size - 1 + post_num])
          return
        end
      end
      do_send_core(fargs, 0, recv, mid, scratch)
    end
  end

  class AttrMethodDef < MethodDef
    def initialize(ivar, kind)
      @ivar = ivar
      @kind = kind # :reader | :writer
    end

    attr_reader :ivar, :kind

    def do_send(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      case @kind
      when :reader
        if aargs.lead_tys.size == 0
          scratch.get_instance_variable(recv, @ivar, caller_ep, caller_env) do |ty, nenv|
            ctn[ty, caller_ep, nenv]
          end
        else
          ctn[Type.any, caller_ep, caller_env]
        end
      when :writer
        if aargs.lead_tys.size == 1
          ty = aargs.lead_tys[0]
          scratch.set_instance_variable(recv, @ivar, ty, caller_ep, caller_env)
          ctn[ty, caller_ep, caller_env]
        else
          ctn[Type.any, caller_ep, caller_env]
        end
      end
    end
  end

  class TypedMethodDef < MethodDef
    def initialize(sigs, rbs_source) # sigs: Array<[FormalArguments, (return)Type]>
      @sigs = sigs
      @rbs_source = rbs_source
    end

    attr_reader :rbs_source

    def do_send(recv_orig, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      recv = scratch.globalize_type(recv_orig, caller_env, caller_ep)
      found = false
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)
      @sigs.each do |fargs, ret_ty|
        ncaller_env = caller_env
        # XXX: need to interpret args more correctly
        #pp [mid, aargs, fargs]
        # XXX: support self type in fargs
        subst = { Type::Var.new(:self) => recv }
        next unless aargs.consistent_with_formal_arguments?(fargs, subst)
        if recv.is_a?(Type::Array) && recv_orig.is_a?(Type::LocalArray)
          tyvar_elem = Type::Var.new(:Elem)
          if subst[tyvar_elem]
            ty = subst[tyvar_elem]
            alloc_site = AllocationSite.new(caller_ep).add_id(self)
            ncaller_env, ty = scratch.localize_type(ty, ncaller_env, caller_ep)
            ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id) do |elems|
              elems.update(nil, ty)
            end
          end
          subst.merge!({ tyvar_elem => recv.elems.squash })
        elsif recv.is_a?(Type::Hash) && recv_orig.is_a?(Type::LocalHash)
          tyvar_k = Type::Var.new(:K)
          tyvar_v = Type::Var.new(:V)
          # XXX: need to support destructive operation
          k_ty, v_ty = recv.elems.squash
          # XXX: need to heuristically replace ret type Hash[K, V] with self, instead of conversative type?
          subst.merge!({ tyvar_k => k_ty, tyvar_v => v_ty })
        end
        ret_ty = ret_ty.substitute(subst, Config.options[:type_depth_limit])
        found = true
        if aargs.blk_ty.is_a?(Type::ISeqProc)
          dummy_ctx = TypedContext.new(caller_ep, mid)
          dummy_ep = ExecutionPoint.new(dummy_ctx, -1, caller_ep)
          dummy_env = Env.new(StaticEnv.new(recv, fargs.blk_ty, false), [], [], Utils::HashWrapper.new({}))
          if fargs.blk_ty.is_a?(Type::TypedProc)
            scratch.add_callsite!(dummy_ctx, nil, caller_ep, ncaller_env, &ctn)
            nfargs = fargs.blk_ty.fargs
            alloc_site = AllocationSite.new(caller_ep).add_id(self)
            nlead_tys = (nfargs.lead_tys + nfargs.opt_tys).map.with_index do |ty, i|
              if recv.is_a?(Type::Array)
                tyvar_elem = Type::Var.new(:Elem)
                ty = ty.substitute(subst.merge({ tyvar_elem => recv.elems.squash }), Config.options[:type_depth_limit])
              else
                ty = ty.substitute(subst, Config.options[:type_depth_limit])
              end
              ty = ty.remove_type_vars
              alloc_site2 = alloc_site.add_id(i)
              dummy_env, ty = scratch.localize_type(ty, dummy_env, dummy_ep, alloc_site2)
              ty
            end
            0.upto(nfargs.opt_tys.size) do |n|
              naargs = ActualArguments.new(nlead_tys[0, nfargs.lead_tys.size + n], nil, nil, Type.nil) # XXX: support block to block?
              scratch.do_invoke_block(false, aargs.blk_ty, naargs, dummy_ep, dummy_env) do |blk_ret_ty, _ep, _env|
                subst2 = {}
                if blk_ret_ty.consistent?(fargs.blk_ty.ret_ty, subst2)
                  if recv.is_a?(Type::Array) && recv_orig.is_a?(Type::LocalArray)
                    tyvar_elem = Type::Var.new(:Elem)
                    if subst2[tyvar_elem]
                      ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id) do |elems|
                        elems.update(nil, subst2[tyvar_elem])
                      end
                      scratch.merge_return_env(caller_ep) {|env| env ? env.merge(ncaller_env) : ncaller_env }
                    end
                    ret_ty = ret_ty.substitute(subst2, Config.options[:type_depth_limit])
                  else
                    ret_ty = ret_ty.substitute(subst2, Config.options[:type_depth_limit])
                  end
                else
                  # raise "???"
                  # XXX: need warning
                  ret_ty = Type.any
                end
                ret_ty = ret_ty.remove_type_vars
                # XXX: check the return type from the block
                # sig.blk_ty.ret_ty.eql?(_ret_ty) ???
                scratch.add_return_type!(dummy_ctx, ret_ty)
              end
              # scratch.add_return_type!(dummy_ctx, ret_ty) ?
              # This makes `def foo; 1.times { return "str" }; end` return Integer|String
            end
          else
            # XXX: a block is passed to a method that does not accept block.
            # Should we call the passed block with any arguments?
            ret_ty = ret_ty.remove_type_vars
            ctn[ret_ty, caller_ep, ncaller_env]
          end
        else
          ret_ty = ret_ty.remove_type_vars
          ctn[ret_ty, caller_ep, ncaller_env]
        end
      end

      unless found
        scratch.error(caller_ep, "failed to resolve overload: #{ recv.screen_name(scratch) }##{ mid }")
        ctn[Type.any, caller_ep, caller_env]
      end
    end

    def do_match_iseq_mdef(iseq_mdef, recv, mid, env, ep, scratch)
      recv = scratch.globalize_type(recv, env, ep)
      @sigs.each do |fargs, _ret_ty|
        iseq_mdef.do_check_send_core(fargs, recv, mid, ep, scratch)
      end
    end
  end

  class CustomMethodDef < MethodDef
    def initialize(impl)
      @impl = impl
    end

    def do_send(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      # XXX: ctn?
      scratch.merge_return_env(caller_ep) {|env| env ? env.merge(caller_env) : caller_env } # for Kernel#lambda
      @impl[recv, mid, aargs, caller_ep, caller_env, scratch, &ctn]
    end
  end
end
