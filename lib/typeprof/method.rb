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
      recv = recv.base_type while recv.respond_to?(:base_type)
      recv = scratch.globalize_type(recv, caller_env, caller_ep)
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)

      locals = [Type.nil] * @iseq.locals.size

      blk_ty, start_pcs = aargs.setup_formal_arguments(:method, locals, @iseq.fargs_format)
      if blk_ty.is_a?(String)
        scratch.error(caller_ep, blk_ty)
        ctn[Type.any, caller_ep, caller_env]
        return
      end

      nctx = Context.new(@iseq, @cref, mid)
      callee_ep = ExecutionPoint.new(nctx, 0, nil)
      nenv = Env.new(StaticEnv.new(recv, blk_ty, false), locals, [], Utils::HashWrapper.new({}))
      alloc_site = AllocationSite.new(callee_ep)
      locals.each_with_index do |ty, i|
        alloc_site2 = alloc_site.add_id(i)
        # nenv is top-level, so it is okay to call Type#localize directly
        nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
        nenv = nenv.local_update(i, ty)
      end

      start_pcs.each do |start_pc|
        scratch.merge_env(ExecutionPoint.new(nctx, start_pc, @outer_ep), nenv)
      end

      scratch.add_iseq_method_call!(self, nctx)
      scratch.add_callsite!(nctx, caller_ep, caller_env, &ctn)
    end

    def do_check_send(msig, recv, mid, ep, scratch)
      lead_num = @iseq.fargs_format[:lead_num] || 0
      post_num = @iseq.fargs_format[:post_num] || 0
      rest_start = @iseq.fargs_format[:rest_start]
      opt = @iseq.fargs_format[:opt] || [0]

      # TODO: check keywords
      if rest_start
        # almost ok
      else
        if msig.lead_tys.size + msig.post_tys.size < lead_num + post_num
          scratch.error(ep, "RBS says that the arity may be %d, but the method definition requires at least %d arguments" % [msig.lead_tys.size + msig.post_tys.size, lead_num + post_num])
          return
        end
        if msig.lead_tys.size + msig.opt_tys.size + msig.post_tys.size > lead_num + opt.size - 1 + post_num
          scratch.error(ep, "RBS says that the arity may be %d, but the method definition requires at most %d arguments" % [msig.lead_tys.size + msig.opt_tys.size + msig.post_tys.size, lead_num + opt.size - 1 + post_num])
          return
        end
      end

      lead_num = @iseq.fargs_format[:lead_num] || 0
      post_start = @iseq.fargs_format[:post_start]
      rest_start = @iseq.fargs_format[:rest_start]
      kw_start = @iseq.fargs_format[:kwbits]
      kw_start -= @iseq.fargs_format[:keyword].size if kw_start
      kw_rest = @iseq.fargs_format[:kwrest]
      block_start = @iseq.fargs_format[:block_start]

      # XXX: need to check .rbs msig and .rb fargs

      ctx = Context.new(@iseq, @cref, mid)
      callee_ep = ExecutionPoint.new(ctx, 0, nil)

      locals = [Type.nil] * @iseq.locals.size
      nenv = Env.new(StaticEnv.new(recv, msig.blk_ty, false), locals, [], Utils::HashWrapper.new({}))
      alloc_site = AllocationSite.new(callee_ep)
      idx = 0
      msig.lead_tys.each_with_index do |ty, i|
        alloc_site2 = alloc_site.add_id(idx += 1)
        # nenv is top-level, so it is okay to call Type#localize directly
        nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
        nenv = nenv.local_update(i, ty)
      end
      if msig.opt_tys
        msig.opt_tys.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
          nenv = nenv.local_update(lead_num + i, ty)
        end
      end
      if msig.rest_ty
        alloc_site2 = alloc_site.add_id(idx += 1)
        ty = Type::Array.new(Type::Array::Elements.new([], msig.rest_ty), Type::Instance.new(Type::Builtin[:ary]))
        nenv, rest_ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
        nenv = nenv.local_update(rest_start, rest_ty)
      end
      if msig.post_tys
        msig.post_tys.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(idx += 1)
          nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
          nenv = nenv.local_update(post_start + i, ty)
        end
      end
      if msig.kw_tys
        msig.kw_tys.each_with_index do |(_, key, ty), i|
          alloc_site2 = alloc_site.add_id(key)
          nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
          nenv = nenv.local_update(kw_start + i, ty)
        end
      end
      if msig.kw_rest_ty
        ty = msig.kw_rest_ty
        alloc_site2 = alloc_site.add_id(:**)
        nenv, ty = ty.localize(nenv, alloc_site2, Config.options[:type_depth_limit])
        nenv = nenv.local_update(kw_rest, ty)
      end
      nenv = nenv.local_update(block_start, msig.blk_ty) if block_start

      opt.each do |start_pc|
        scratch.merge_env(ExecutionPoint.new(ctx, start_pc, nil), nenv)
      end

      ctx
    end
  end

  class AttrMethodDef < MethodDef
    def initialize(ivar, kind, absolute_path)
      @ivar = ivar
      @kind = kind # :reader | :writer
      @absolute_path = absolute_path
    end

    attr_reader :ivar, :kind, :absolute_path

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
    def initialize(sig_rets, rbs_source) # sig_rets: Array<[MethodSignature, (return)Type]>
      @sig_rets = sig_rets
      @rbs_source = rbs_source
    end

    attr_reader :rbs_source

    def do_send(recv_orig, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      recv = scratch.globalize_type(recv_orig, caller_env, caller_ep)
      found = false
      aargs = scratch.globalize_type(aargs, caller_env, caller_ep)
      @sig_rets.each do |msig, ret_ty|
        ncaller_env = caller_env
        #pp [mid, aargs, msig]
        # XXX: support self type in msig
        subst = aargs.consistent_with_method_signature?(msig)
        next unless subst
        # need to check self tyvar?
        subst[Type::Var.new(:self)] = recv
        case
        when recv.is_a?(Type::Cell) && recv_orig.is_a?(Type::LocalCell)
          tyvars = recv.base_type.klass.type_params.map {|name,| Type::Var.new(name) }
          tyvars.each_with_index do |tyvar, idx|
            ty = subst[tyvar]
            if ty
              ncaller_env, ty = scratch.localize_type(ty, ncaller_env, caller_ep)
              ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id, recv_orig.base_type) do |elems|
                elems.update(idx, ty)
              end
            end
          end
          tyvars.zip(recv.elems.elems) do |tyvar, elem|
            if subst[tyvar]
              subst[tyvar] = subst[tyvar].union(elem)
            else
              subst[tyvar] = elem
            end
          end
        when recv.is_a?(Type::Array) && recv_orig.is_a?(Type::LocalArray)
          tyvar_elem = Type::Var.new(:Elem)
          if subst[tyvar_elem]
            ty = subst[tyvar_elem]
            ncaller_env, ty = scratch.localize_type(ty, ncaller_env, caller_ep)
            ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id, recv_orig.base_type) do |elems|
              elems.update(nil, ty)
            end
          end
          subst.merge!({ tyvar_elem => recv.elems.squash })
        when recv.is_a?(Type::Hash) && recv_orig.is_a?(Type::LocalHash)
          tyvar_k = Type::Var.new(:K)
          tyvar_v = Type::Var.new(:V)
          k_ty0, v_ty0 = recv.elems.squash
          if subst[tyvar_k] && subst[tyvar_v]
            k_ty = subst[tyvar_k]
            v_ty = subst[tyvar_v]
            k_ty0 = k_ty0.union(k_ty)
            v_ty0 = v_ty0.union(v_ty)
            alloc_site = AllocationSite.new(caller_ep)
            ncaller_env, k_ty = scratch.localize_type(k_ty, ncaller_env, caller_ep, alloc_site.add_id(:k))
            ncaller_env, v_ty = scratch.localize_type(v_ty, ncaller_env, caller_ep, alloc_site.add_id(:v))
            ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id, recv_orig.base_type) do |elems|
              elems.update(k_ty, v_ty)
            end
          end
          # XXX: need to heuristically replace ret type Hash[K, V] with self, instead of conversative type?
          subst.merge!({ tyvar_k => k_ty0, tyvar_v => v_ty0 })
        end
        found = true
        if aargs.blk_ty.is_a?(Type::Proc)
          #raise NotImplementedError unless aargs.blk_ty.block_body.is_a?(ISeqBlock) # XXX
          dummy_ctx = TypedContext.new(caller_ep, mid)
          dummy_ep = ExecutionPoint.new(dummy_ctx, -1, caller_ep)
          s_recv = recv
          s_recv = s_recv.base_type while s_recv.respond_to?(:base_type)
          dummy_env = Env.new(StaticEnv.new(s_recv, msig.blk_ty, false), [], [], Utils::HashWrapper.new({}))
          if msig.blk_ty.is_a?(Type::Proc)
            scratch.add_callsite!(dummy_ctx, caller_ep, ncaller_env, &ctn)
            nfargs = msig.blk_ty.block_body.msig
            alloc_site = AllocationSite.new(caller_ep).add_id(self)
            nlead_tys = (nfargs.lead_tys + nfargs.opt_tys).map.with_index do |ty, i|
              if recv.is_a?(Type::Array)
                tyvar_elem = Type::Var.new(:Elem)
                ty = ty.substitute(subst.merge({ tyvar_elem => recv.elems.squash_or_any }), Config.options[:type_depth_limit])
              else
                ty = ty.substitute(subst, Config.options[:type_depth_limit])
              end
              ty = ty.remove_type_vars
              alloc_site2 = alloc_site.add_id(i)
              dummy_env, ty = scratch.localize_type(ty, dummy_env, dummy_ep, alloc_site2)
              ty
            end
            0.upto(nfargs.opt_tys.size) do |n|
              naargs = ActualArguments.new(nlead_tys[0, nfargs.lead_tys.size + n], nil, {}, Type.nil) # XXX: support block to block?
              scratch.do_invoke_block(aargs.blk_ty, naargs, dummy_ep, dummy_env) do |blk_ret_ty, _ep, _env|
                subst2 = Type.match?(blk_ret_ty, msig.blk_ty.block_body.ret_ty)
                if subst2
                  subst2 = Type.merge_substitution(subst, subst2)
                  case
                  when recv.is_a?(Type::Cell) && recv_orig.is_a?(Type::LocalCell)
                    tyvars = recv.base_type.klass.type_params.map {|name,| Type::Var.new(name) }
                    tyvars.each_with_index do |tyvar, idx|
                      ty = subst2[tyvar]
                      if ty
                        ncaller_env, ty = scratch.localize_type(ty, ncaller_env, caller_ep)
                        ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id, recv_orig.base_type) do |elems|
                          elems.update(idx, ty)
                        end
                        scratch.merge_return_env(caller_ep) {|env| env ? env.merge(ncaller_env) : ncaller_env }
                      end
                    end
                    tyvars.zip(recv.elems.elems) do |tyvar, elem|
                      if subst2[tyvar]
                        subst2[tyvar] = subst2[tyvar].union(elem)
                      else
                        subst2[tyvar] = elem
                      end
                    end
                    ret_ty = ret_ty.substitute(subst2, Config.options[:type_depth_limit])
                  when recv.is_a?(Type::Array) && recv_orig.is_a?(Type::LocalArray)
                    tyvar_elem = Type::Var.new(:Elem)
                    if subst2[tyvar_elem]
                      ty = subst2[tyvar_elem]
                      ncaller_env, ty = scratch.localize_type(ty, ncaller_env, caller_ep)
                      ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id, recv_orig.base_type) do |elems|
                        elems.update(nil, ty)
                      end
                      scratch.merge_return_env(caller_ep) {|env| env ? env.merge(ncaller_env) : ncaller_env }
                    end
                    ret_ty = ret_ty.substitute(subst2, Config.options[:type_depth_limit])
                  when recv.is_a?(Type::Hash) && recv_orig.is_a?(Type::LocalHash)
                    tyvar_k = Type::Var.new(:K)
                    tyvar_v = Type::Var.new(:V)
                    k_ty0, v_ty0 = recv.elems.squash
                    if subst2[tyvar_k] && subst2[tyvar_v]
                      k_ty = subst2[tyvar_k]
                      v_ty = subst2[tyvar_v]
                      k_ty0 = k_ty0.union(k_ty)
                      v_ty0 = v_ty0.union(v_ty)
                      alloc_site = AllocationSite.new(caller_ep)
                      ncaller_env, k_ty = scratch.localize_type(k_ty, ncaller_env, caller_ep, alloc_site.add_id(:k))
                      ncaller_env, v_ty = scratch.localize_type(v_ty, ncaller_env, caller_ep, alloc_site.add_id(:v))
                      ncaller_env = scratch.update_container_elem_types(ncaller_env, caller_ep, recv_orig.id, recv_orig.base_type) do |elems|
                        elems.update(k_ty, v_ty)
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
                # sig.blk_ty.block_body.ret_ty.eql?(_ret_ty) ???
                scratch.add_return_value!(dummy_ctx, ret_ty)
              end
              # scratch.add_return_value!(dummy_ctx, ret_ty) ?
              # This makes `def foo; 1.times { return "str" }; end` return Integer|String
            end
          else
            # XXX: a block is passed to a method that does not accept block.
            # Should we call the passed block with any arguments?
            ret_ty = ret_ty.remove_type_vars
            ctn[ret_ty, caller_ep, ncaller_env]
          end
        else
          ret_ty = ret_ty.substitute(subst, Config.options[:type_depth_limit])
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
      @sig_rets.each do |msig, _ret_ty|
        iseq_mdef.do_check_send(msig, recv, mid, ep, scratch)
      end
    end
  end

  class CustomMethodDef < MethodDef
    def initialize(impl)
      @impl = impl
    end

    def do_send(recv, mid, aargs, caller_ep, caller_env, scratch, &ctn)
      scratch.merge_return_env(caller_ep) {|env| env ? env.merge(caller_env) : caller_env } # for Kernel#lambda
      @impl[recv, mid, aargs, caller_ep, caller_env, scratch, &ctn]
    end
  end
end
