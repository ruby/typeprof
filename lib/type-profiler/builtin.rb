module TypeProfiler
  module Builtin
    module_function

    def get_sym(target, ty)
      raise "symbol expected" unless ty.is_a?(Type::Symbol)
      sym = ty.sym
      unless sym
        scratch.warn(ep, "dynamic symbol is given to #{ target }; ignored")
        return
      end
      sym
    end

    def vmcore_set_method_alias(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      klass, new_mid, old_mid = aargs.lead_tys
      new_sym = get_sym("alias", new_mid) or return
      old_sym = get_sym("alias", old_mid) or return
      scratch.alias_method(klass, ep.ctx.singleton, new_sym, old_sym)
      ctn[Type.nil, ep, env]
    end

    def vmcore_undef_method(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      # no-op
      ctn[Type.nil, ep, env]
    end

    def lambda(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      ctn[aargs.blk_ty, ep, env]
    end

    def proc_call(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      given_block = env.blk_ty == recv
      Scratch::Aux.do_invoke_block(given_block, recv, aargs, ep, env, scratch, &ctn)
    end

    def object_new(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      ty = Type::Instance.new(recv)
      meths = scratch.get_method(recv, :initialize)
      meths.flat_map do |meth|
        meth.do_send(0, ty, :initialize, aargs, ep, env, scratch) do |ret_ty, ep, env|
          ctn[Type::Instance.new(recv), ep, env]
        end
      end
    end

    def object_is_a?(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise unless aargs.lead_tys.size != 0
      if recv.is_a?(Type::Instance)
        if recv.klass == aargs.lead_tys[0] # XXX: inheritance
          true_val = Type::Instance.new(Type::Builtin[:true])
          ctn[true_val, ep, env]
        else
          false_val = Type::Instance.new(Type::Builtin[:false])
          ctn[false_val, ep, env]
        end
      else
        ctn[Type.bool, ep, env]
      end
    end

    def object_class(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      if recv.is_a?(Type::Instance)
        ctn[recv.klass, ep, env]
      else
        ctn[Type.any, ep, env]
      end
    end

    def add_attr_reader(sym, cref, scratch)
      iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[0][2]
      scratch.add_iseq_method(cref.klass, sym, iseq_getter, cref)
    end

    def add_attr_writer(sym, cref, scratch)
      iseq_setter = ISeq.compile_str("def #{ sym }=(x); @#{ sym } = x; end").insns[0][2]
      scratch.add_iseq_method(cref.klass, :"#{ sym }=", iseq_setter, cref)
    end

    def module_attr_accessor(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_accessor", aarg) or next
        cref = ep.ctx.cref
        add_attr_reader(sym, cref, scratch)
        add_attr_writer(sym, cref, scratch)
      end
      ctn[Type.nil, ep, env]
    end

    def module_attr_reader(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_reader", aarg) or next
        cref = ep.ctx.cref
        add_attr_reader(sym, cref, scratch)
      end
      ctn[Type.nil, ep, env]
    end

    def module_attr_writer(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_writer", aarg) or next
        cref = ep.ctx.cref
        add_attr_writer(sym, cref, scratch)
      end
      ctn[Type.nil, ep, env]
    end

    def reveal_type(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        scratch.reveal_type(ep, aarg.strip_local_info(env).screen_name(scratch))
      end
      ctn[aargs.lead_tys.size == 1 ? aargs.lead_tys.first : Type.any, ep, env]
    end

    def array_aref(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      idx = aargs.lead_tys.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      ty = scratch.get_array_elem_type(env, ep, recv.id, idx)
      ctn[ty, ep, env]
    end

    def array_aset(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 2
      idx = aargs.lead_tys.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      ty = aargs.lead_tys.last

      nenv = env.poke_array_elem_types(recv.id, idx, ty)
      if nenv
        env = nenv
      else
        tmp_ep, tmp_env = ep, env
        until ntmp_env = tmp_env.poke_array_elem_types(recv.id, idx, ty)
          tmp_ep = tmp_ep.outer
          tmp_env = scratch.return_envs[tmp_ep]
        end
        scratch.merge_return_env(tmp_ep) do |_env|
          ntmp_env
        end
      end
      ctn[ty, ep, env]
    end

    def array_ltlt(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1

      ty = aargs.lead_tys.first

      nenv = env.append_array_elem_types(recv.id, ty)
      if nenv
        env = nenv
      else
        tmp_ep, tmp_env = ep, env
        until ntmp_env = tmp_env.append_array_elem_types(recv.id, ty)
          tmp_ep = tmp_ep.outer
          tmp_env = scratch.return_envs[tmp_ep]
        end
        scratch.merge_return_env(tmp_ep) do |_env|
          ntmp_env
        end
      end
      ctn[recv, ep, env]
    end

    def array_each(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 0
      ty = scratch.get_array_elem_type(env, ep, recv.id)
      naargs = ActualArguments.new([ty], nil, Type.nil)
      Scratch::Aux.do_invoke_block(false, aargs.blk_ty, naargs, ep, env, scratch) do |_ret_ty, ep|
        ctn[recv, ep, scratch.return_envs[ep]] # XXX: refactor "scratch.return_envs"
      end
    end

    def array_map(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 0
      ty = scratch.get_array_elem_type(env, ep, recv.id)
      naargs = ActualArguments.new([ty], nil, Type.nil)
      Scratch::Aux.do_invoke_block(false, aargs.blk_ty, naargs, ep, env, scratch) do |ret_ty, ep|
        ctn[Type::Array.seq(ret_ty), ep, scratch.return_envs[ep]] # XXX: refactor "scratch.return_envs"
      end
    end

    def array_plus(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      ary = aargs.lead_tys.first
      elems1 = scratch.get_array_elem_type(env, ep, recv.id)
      if ary.is_a?(Type::LocalArray)
        elems2 = scratch.get_array_elem_type(env, ep, ary.id)
        elems = Type::Array::Seq.new(elems1.union(elems2))
        env, ty, = env.deploy_array_type(recv.base_type, elems, recv.base_type)
        ctn[ty, ep, env]
      else
        # warn??
        ctn[Type.any, ep, env]
      end
    end

    def array_pop(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      if aargs.lead_tys.size != 0
        env[Type.any, ep, env]
      end

      ty = scratch.get_array_elem_type(env, ep, recv.id)
      ctn[ty, ep, env]
    end

    def array_include?(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      ctn[Type.bool, ep, env]
    end

    def file_load(path, ep, env, scratch, &ctn)
      iseq = ISeq.compile(path)
      callee_ep, callee_env = TypeProfiler.starting_state(iseq)
      scratch.merge_env(callee_ep, callee_env)

      scratch.add_callsite!(callee_ep.ctx, nil, ep, env) do |_ret_ty, ep|
        ret_ty = Type::Instance.new(Type::Builtin[:true])
        ctn[ret_ty, ep, env]
      end
    end

    def kernel_require(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      feature = aargs.lead_tys.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        filetype, path = $LOAD_PATH.resolve_feature_path(feature)
        if filetype == :rb
          return file_load(path, ep, env, scratch, &ctn) if File.readable?(path)

          scratch.warn(ep, "failed to read: #{ path }")
        else
          scratch.warn(ep, "failed to read a .so file: #{ path }")
        end
      else
        scratch.warn(ep, "require target cannot be identified statically")
      end

      result = Type::Instance.new(Type::Builtin[:true])
      scratch[result, ep, env]
    end

    def kernel_require_relative(flags, recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      feature = aargs.lead_tys.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        path = File.join(File.dirname(ep.ctx.iseq.path), feature) + ".rb" # XXX
        if File.readable?(path)
          iseq = ISeq.compile(path)
          callee_ep, callee_env = TypeProfiler.starting_state(iseq)
          scratch.merge_env(callee_ep, callee_env)

          scratch.add_callsite!(callee_ep.ctx, nil, ep, env) do |_ret_ty, ep|
            result = Type::Instance.new(Type::Builtin[:true])
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

      result = Type::Instance.new(Type::Builtin[:true])
      scratch[result, ep, env]
    end
  end

  def self.setup_initial_global_env(scratch)
    klass_obj = scratch.new_class(nil, :Object, nil) # cbase, name, superclass
    scratch.add_constant(klass_obj, "Object", klass_obj)
    klass_true  = scratch.new_class(klass_obj, :TrueClass, klass_obj) # ???
    klass_false = scratch.new_class(klass_obj, :FalseClass, klass_obj) # ???
    klass_nil = scratch.new_class(klass_obj, :NilClass, klass_obj) # ???

    Type::Builtin[:obj]   = klass_obj
    Type::Builtin[:true]  = klass_true
    Type::Builtin[:false] = klass_false
    Type::Builtin[:nil]   = klass_nil

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
    klass_class     = scratch.get_constant(klass_obj, :Class)
    klass_module    = scratch.get_constant(klass_obj, :Module)

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
    Type::Builtin[:class]     = klass_class
    Type::Builtin[:module]    = klass_module

    scratch.add_custom_method(klass_vmcore, :"core#set_method_alias", Builtin.method(:vmcore_set_method_alias))
    scratch.add_custom_method(klass_vmcore, :"core#undef_method", Builtin.method(:vmcore_undef_method))
    scratch.add_custom_method(klass_vmcore, :lambda, Builtin.method(:lambda))
    scratch.add_singleton_custom_method(klass_obj, :"new", Builtin.method(:object_new))
    scratch.add_singleton_custom_method(klass_obj, :"attr_accessor", Builtin.method(:module_attr_accessor))
    scratch.add_singleton_custom_method(klass_obj, :"attr_reader", Builtin.method(:module_attr_reader))
    scratch.add_singleton_custom_method(klass_obj, :"attr_writer", Builtin.method(:module_attr_writer))
    scratch.add_custom_method(klass_obj, :p, Builtin.method(:reveal_type))
    scratch.add_custom_method(klass_obj, :is_a?, Builtin.method(:object_is_a?))
    scratch.add_custom_method(klass_obj, :class, Builtin.method(:object_class))
    scratch.add_custom_method(klass_proc, :[], Builtin.method(:proc_call))
    scratch.add_custom_method(klass_proc, :call, Builtin.method(:proc_call))
    scratch.add_custom_method(klass_ary, :[], Builtin.method(:array_aref))
    scratch.add_custom_method(klass_ary, :[]=, Builtin.method(:array_aset))
    scratch.add_custom_method(klass_ary, :<<, Builtin.method(:array_ltlt))
    scratch.add_custom_method(klass_ary, :each, Builtin.method(:array_each))
    scratch.add_custom_method(klass_ary, :map, Builtin.method(:array_map))
    scratch.add_custom_method(klass_ary, :+, Builtin.method(:array_plus))
    scratch.add_custom_method(klass_ary, :pop, Builtin.method(:array_pop))
    scratch.add_custom_method(klass_ary, :include?, Builtin.method(:array_include?))

    i = -> t { Type::Instance.new(t) }

    scratch.add_typed_method(i[klass_obj], :==, FormalArguments.new([Type.any], [], nil, [], nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_obj], :!=, FormalArguments.new([Type.any], [], nil, [], nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_obj], :initialize, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_nil])
    scratch.add_typed_method(i[klass_int], :< , FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_int], :<=, FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_int], :>=, FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_int], :> , FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), Type.bool)
    #scratch.add_typed_method(i[klass_int], :+ , FormalArguments.new([i[klass_int]], nil, nil, nil, nil, i[klass_nil]), i[klass_int])
    scratch.add_typed_method(i[klass_int], :- , FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil]), i[klass_int])
    int_times_blk = Type::TypedProc.new([i[klass_int]], Type.any, Type::Builtin[:proc])
    scratch.add_typed_method(i[klass_int], :times, FormalArguments.new([], [], nil, [], nil, int_times_blk), i[klass_int])
    scratch.add_typed_method(i[klass_int], :to_s, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_s, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_sym], :to_s, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_sym, FormalArguments.new([], [], nil, [], nil, i[klass_nil]), i[klass_sym])
    scratch.add_typed_method(i[klass_str], :+ , FormalArguments.new([i[klass_str]], [], nil, [], nil, i[klass_nil]), i[klass_str])

    fargs1 = FormalArguments.new([i[klass_int]], [], nil, [], nil, i[klass_nil])
    fargs2 = FormalArguments.new([i[klass_str]], [], nil, [], nil, i[klass_nil])
    mdef = TypedMethodDef.new([[fargs1, i[klass_int]], [fargs2, i[klass_int]]])
    scratch.add_method(klass_obj, :Integer, mdef)

    scratch.add_custom_method(klass_obj, :require, Builtin.method(:kernel_require))
    scratch.add_custom_method(klass_obj, :require_relative, Builtin.method(:kernel_require_relative))
  end
end
