module TypeProfiler
  module Builtin
    module_function

    def vmcore_define_method(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      mid, iseq = aargs.lead_tys
      cref = ep.ctx.cref
      sym = mid.lit
      raise "symbol expected" unless sym.is_a?(Symbol)
      scratch.add_iseq_method(cref.klass, sym, iseq.iseq, cref)
      ctn[mid, ep, env]
    end

    def vmcore_define_singleton_method(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      recv_ty, mid, iseq = aargs.lead_tys
      cref = ep.ctx.cref
      sym = mid.lit
      raise "symbol expected" unless sym.is_a?(Symbol)
      scratch.add_singleton_iseq_method(recv_ty, sym, iseq.iseq, cref)
      ctn[mid, ep, env]
    end

    def vmcore_set_method_alias(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      klass, new_mid, old_mid = aargs.lead_tys
      new_sym = new_mid.lit
      raise "symbol expected" unless new_sym.is_a?(Symbol)
      old_sym = old_mid.lit
      raise "symbol expected" unless old_sym.is_a?(Symbol)
      scratch.alias_method(klass, new_sym, old_sym)
      ty = Type::Instance.new(Type::Builtin[:nil])
      ctn[ty, ep, env]
    end

    def lambda(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      ctn[aargs.blk_ty, ep, env]
    end

    def proc_call(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      given_block = ep.ctx.sig.fargs.blk_ty == recv
      Scratch::Aux.do_invoke_block(given_block, recv, aargs, ep, env, scratch, &ctn)
    end

    def object_new(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      ty = Type::Instance.new(recv)
      meths = scratch.get_method(recv, :initialize)
      meths.flat_map do |meth|
        meth.do_send(state, 0, ty, :initialize, aargs, ep, env, scratch) do |ret_ty, ep, env|
          ctn[Type::Instance.new(recv), ep, env]
        end
      end
    end

    def object_is_a?(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise unless aargs.lead_tys.size != 0
      if recv.is_a?(Type::Instance)
        if recv.klass == aargs.lead_tys[0] # XXX: inheritance
          true_val = Type::Literal.new(true, Type::Instance.new(Type::Builtin[:bool]))
          ctn[true_val, ep, env]
        else
          false_val = Type::Literal.new(false, Type::Instance.new(Type::Builtin[:bool]))
          ctn[false_val, ep, env]
        end
      else
        bool = Type::Instance.new(Type::Builtin[:bool])
        ctn[bool, ep, env]
      end
    end

    def module_attr_accessor(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = aarg.lit
        cref = ep.ctx.cref
        raise "symbol expected" unless sym.is_a?(Symbol)
        iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[2][1]
        iseq_setter = ISeq.compile_str("def #{ sym }=(x); @#{ sym } = x; end").insns[2][1]
        scratch.add_iseq_method(cref.klass, sym, iseq_getter, cref)
        scratch.add_iseq_method(cref.klass, :"#{ sym }=", iseq_setter, cref)
      end
      ty = Type::Instance.new(Type::Builtin[:nil])
      ctn[ty, ep, env]
    end

    def module_attr_reader(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = aarg.lit
        cref = ep.ctx.cref
        raise "symbol expected" unless sym.is_a?(Symbol)
        iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[2][1]
        scratch.add_iseq_method(cref.klass, sym, iseq_getter, cref)
      end
      ty = Type::Instance.new(Type::Builtin[:nil])
      ctn[ty, ep, env]
    end

    def reveal_type(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        scratch.reveal_type(ep, aarg.strip_local_info(env).screen_name(scratch))
      end
      ctn[Type::Any.new, ep, env]
    end

    def array_aref(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      idx = aargs.lead_tys.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      # assumes that recv is LocalArray
      elems = env.get_array_elem_types(recv.id)
      if elems
        if idx
          elem = elems[idx] || Utils::Set[Type::Instance.new(Type::Builtin[:nil])] # HACK
        else
          elem = elems.types
        end
      else
        elem = Utils::Set[Type::Any.new] # XXX
      end
      elem.each do |ty| # TODO: Use Sum type
        ctn[ty, ep, env]
      end
    end

    def array_aset(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 2
      idx = aargs.lead_tys.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      ty = aargs.lead_tys.last

      tmp_ep, tmp_env = ep, env
      until ntmp_env = tmp_env.poke_array_elem_types(recv.id, idx, ty)
        tmp_ep = tmp_ep.outer
        tmp_env = scratch.return_envs[tmp_ep]
      end
      scratch.merge_return_env(tmp_ep) do |_env|
        ntmp_env
      end
      ctn[ty, ep, env]
    end

    def array_each(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 0
      elems = env.get_array_elem_types(recv.id)
      elems = elems ? elems.types : [Type::Any.new]
      ty = Type::Sum.new(elems)
      blk_nil = Type::Instance.new(Type::Builtin[:nil])
      naargs = ActualArguments.new([ty], nil, blk_nil)
      Scratch::Aux.do_invoke_block(false, aargs.blk_ty, naargs, ep, env, scratch) do |_ret_ty, ep|
        ctn[recv, ep, scratch.return_envs[ep]] # XXX: refactor "scratch.return_envs"
      end
    end

    def array_plus(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      ary = aargs.lead_tys.first
      elems1 = env.get_array_elem_types(recv.id)
      if ary.is_a?(Type::LocalArray)
        elems2 = env.get_array_elem_types(ary.id)
        elems = Type::Array::Seq.new(elems1.types + elems2.types.map {|ty| ty.strip_local_info(env) })
        env, ty, = env.deploy_array_type(recv.base_type, elems, recv.base_type)
        ctn[ty, ep, env]
      else
        # warn??
        ctn[Type::Any.new, ep, env]
      end
    end

    def array_pop(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      if aargs.lead_tys.size != 0
        env[Type::Any.new, ep, env]
      end

      elems = env.get_array_elem_types(recv.id)
      elems.types.each do |ty| # TODO: use Sum type
        ctn[ty, ep, env]
      end
    end

    def require_relative(state, flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      feature = aargs.lead_tys.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        path = File.join(File.dirname(ep.ctx.iseq.path), feature) + ".rb" # XXX
        if File.readable?(path)
          iseq = ISeq.compile(path)
          callee_ep, callee_env = TypeProfiler.starting_state(iseq)
          scratch.merge_env(callee_ep, callee_env)

          scratch.add_callsite!(callee_ep.ctx, ep, env) do |_ret_ty, ep|
            result = Type::Literal.new(true, Type::Instance.new(Type::Builtin[:bool]))
            ctn[result, ep, env]
          end
          return
        else
          scratch.warn(ep, "failed to read: #{ path }")
        end
      else
        scratch.warn(ep, "require target cannot be identified statically")
        feature = nil
      end

      result = Type::Literal.new(true, Type::Instance.new(Type::Builtin[:bool]))
      scratch[result, ep, env]
    end
  end

  def self.setup_initial_global_env(scratch)
    klass_obj = scratch.new_class(nil, :Object, nil) # cbase, name, superclass
    scratch.add_constant(klass_obj, "Object", klass_obj)
    klass_bool = scratch.new_class(klass_obj, :Boolean, klass_obj) # ???
    klass_nil = scratch.new_class(klass_obj, :NilClass, klass_obj) # ???

    Type::Builtin[:obj]  = klass_obj
    Type::Builtin[:bool] = klass_bool
    Type::Builtin[:nil]  = klass_nil

    TypeProfiler::RubySignatureImporter.import_ruby_signatures(scratch)

    klass_vmcore    = scratch.new_class(klass_obj, :VMCore, klass_obj)
    klass_int       = scratch.get_constant(klass_obj, :Integer)
    klass_float     = scratch.get_constant(klass_obj, :Float)
    klass_sym       = scratch.get_constant(klass_obj, :Symbol)
    klass_str       = scratch.get_constant(klass_obj, :String)
    klass_ary       = scratch.get_constant(klass_obj, :Array)
    klass_proc      = scratch.get_constant(klass_obj, :Proc)
    klass_range     = scratch.get_constant(klass_obj, :Range)
    klass_regexp    = scratch.get_constant(klass_obj, :Regexp)
    klass_matchdata = scratch.get_constant(klass_obj, :MatchData)

    Type::Builtin[:vmcore]    = klass_vmcore
    Type::Builtin[:int]       = klass_int
    Type::Builtin[:float]     = klass_float
    Type::Builtin[:sym]       = klass_sym
    Type::Builtin[:str]       = klass_str
    Type::Builtin[:ary]       = klass_ary
    Type::Builtin[:proc]      = klass_proc
    Type::Builtin[:range]     = klass_range
    Type::Builtin[:regexp]    = klass_regexp
    Type::Builtin[:matchdata] = klass_matchdata

    scratch.add_custom_method(klass_vmcore, :"core#define_method", Builtin.method(:vmcore_define_method))
    scratch.add_custom_method(klass_vmcore, :"core#define_singleton_method", Builtin.method(:vmcore_define_singleton_method))
    scratch.add_custom_method(klass_vmcore, :"core#set_method_alias", Builtin.method(:vmcore_set_method_alias))
    scratch.add_custom_method(klass_vmcore, :lambda, Builtin.method(:lambda))
    scratch.add_singleton_custom_method(klass_obj, :"new", Builtin.method(:object_new))
    scratch.add_singleton_custom_method(klass_obj, :"attr_accessor", Builtin.method(:module_attr_accessor))
    scratch.add_singleton_custom_method(klass_obj, :"attr_reader", Builtin.method(:module_attr_reader))
    scratch.add_custom_method(klass_obj, :p, Builtin.method(:reveal_type))
    scratch.add_custom_method(klass_obj, :is_a?, Builtin.method(:object_is_a?))
    scratch.add_custom_method(klass_proc, :[], Builtin.method(:proc_call))
    scratch.add_custom_method(klass_proc, :call, Builtin.method(:proc_call))
    scratch.add_custom_method(klass_ary, :[], Builtin.method(:array_aref))
    scratch.add_custom_method(klass_ary, :[]=, Builtin.method(:array_aset))
    scratch.add_custom_method(klass_ary, :each, Builtin.method(:array_each))
    scratch.add_custom_method(klass_ary, :+, Builtin.method(:array_plus))
    scratch.add_custom_method(klass_ary, :pop, Builtin.method(:array_pop))

    i = -> t { Type::Instance.new(t) }

    scratch.add_typed_method(i[klass_obj], :==, FormalArguments.new([Type::Any.new], [], nil, [], nil, i[klass_nil]), i[klass_bool])
    scratch.add_typed_method(i[klass_obj], :!=, FormalArguments.new([Type::Any.new], [], nil, [], nil, i[klass_nil]), i[klass_bool])
    scratch.add_typed_method(i[klass_obj], :initialize, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_nil])
    scratch.add_typed_method(i[klass_int], :< , FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), i[klass_bool])
    scratch.add_typed_method(i[klass_int], :<=, FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), i[klass_bool])
    scratch.add_typed_method(i[klass_int], :>=, FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), i[klass_bool])
    scratch.add_typed_method(i[klass_int], :> , FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), i[klass_bool])
    #scratch.add_typed_method(i[klass_int], :+ , FormalArguments.new([i[klass_int]], nil, nil, nil, nil, i[klass_nil]), i[klass_int])
    scratch.add_typed_method(i[klass_int], :- , FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), i[klass_int])
    int_times_blk = Type::TypedProc.new([i[klass_int]], Type::Any.new, Type::Builtin[:proc])
    scratch.add_typed_method(i[klass_int], :times, FormalArguments.new([], [], nil, [], nil, int_times_blk), i[klass_int])
    scratch.add_typed_method(i[klass_int], :to_s, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_s, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_sym], :to_s, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_sym, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_sym])
    scratch.add_typed_method(i[klass_str], :+ , FormalArguments.new([i[klass_str]], [], nil, [], nil, i[klass_nil]), i[klass_str])

    sig1 = Signature.new(i[klass_obj], false, :Integer, FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]))
    sig2 = Signature.new(i[klass_obj], false, :Integer, FormalArguments.new([i[klass_str]], [], nil, [], nil, i[klass_nil]))
    mdef = TypedMethodDef.new([[sig1, i[klass_int]], [sig2, i[klass_int]]])
    scratch.add_method(klass_obj, :Integer, mdef)

    scratch.add_custom_method(klass_obj, :require_relative, Builtin.method(:require_relative))
  end
end
