module TypeProfiler
  module Builtin
    module_function

    def get_sym(target, ty, ep, scratch)
      unless ty.is_a?(Type::Symbol)
        scratch.warn(ep, "symbol expected")
        return
      end
      sym = ty.sym
      unless sym
        scratch.warn(ep, "dynamic symbol is given to #{ target }; ignored")
        return
      end
      sym
    end

    def vmcore_set_method_alias(recv, mid, aargs, ep, env, scratch, &ctn)
      klass, new_mid, old_mid = aargs.lead_tys
      new_sym = get_sym("alias", new_mid, ep, scratch) or return
      old_sym = get_sym("alias", old_mid, ep, scratch) or return
      scratch.alias_method(klass, ep.ctx.cref.singleton, new_sym, old_sym)
      ctn[Type.nil, ep, env]
    end

    def vmcore_undef_method(recv, mid, aargs, ep, env, scratch, &ctn)
      # no-op
      ctn[Type.nil, ep, env]
    end

    def vmcore_hash_merge_kwd(recv, mid, aargs, ep, env, scratch, &ctn)
      h1 = aargs.lead_tys[0]
      h2 = aargs.lead_tys[1]
      elems = nil
      h1.each_child do |h1|
        if h1.is_a?(Type::LocalHash)
          h1_elems = scratch.get_container_elem_types(env, ep, h1.id)
          h2.each_child do |h2|
            if h2.is_a?(Type::LocalHash)
              h2_elems = scratch.get_container_elem_types(env, ep, h2.id)
              elems0 = h1_elems.union(h2_elems)
              if elems
                elems = elems.union(elems0)
              else
                elems = elems0
              end
            end
          end
        end
      end
      elems ||= Type::Hash::Elements.new({Type.any => Type.any})
      base_ty = Type::Instance.new(Type::Builtin[:hash])
      ret_ty = Type::Hash.new(elems, base_ty)
      ctn[ret_ty, ep, env]
    end

    def lambda(recv, mid, aargs, ep, env, scratch, &ctn)
      ctn[aargs.blk_ty, ep, env]
    end

    def proc_call(recv, mid, aargs, ep, env, scratch, &ctn)
      given_block = env.static_env.blk_ty == recv
      scratch.do_invoke_block(given_block, recv, aargs, ep, env, &ctn)
    end

    def object_new(recv, mid, aargs, ep, env, scratch, &ctn)
      ty = Type::Instance.new(recv)
      meths = scratch.get_method(recv, :initialize)
      meths.flat_map do |meth|
        meth.do_send(ty, :initialize, aargs, ep, env, scratch) do |ret_ty, ep, env|
          ctn[Type::Instance.new(recv), ep, env]
        end
      end
    end

    def object_is_a?(recv, mid, aargs, ep, env, scratch, &ctn)
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

    def object_class(recv, mid, aargs, ep, env, scratch, &ctn)
      if recv.is_a?(Type::Instance)
        ctn[recv.klass, ep, env]
      else
        ctn[Type.any, ep, env]
      end
    end

    def object_send(recv, mid, aargs, ep, env, scratch, &ctn)
      if aargs.lead_tys.size >= 1
        mid_ty, = aargs.lead_tys
      else
        mid_ty = aargs.rest_ty
      end
      aargs = ActualArguments.new(aargs.lead_tys[1..-1], aargs.rest_ty, aargs.kw_ty, aargs.blk_ty)
      mid_ty.each_child do |mid|
        if mid.is_a?(Type::Symbol)
          mid = mid.sym
          scratch.do_send(recv, mid, aargs, ep, env)
        end
      end
    end

    def module_include(recv, mid, aargs, ep, env, scratch, &ctn)
      arg = aargs.lead_tys[0]
      scratch.include_module(recv, arg)
      ctn[recv, ep, env]
    end

    def module_extend(recv, mid, aargs, ep, env, scratch, &ctn)
      arg = aargs.lead_tys[0]
      scratch.extend_module(recv, arg)
      ctn[recv, ep, env]
    end

    def module_module_function(recv, mid, aargs, ep, env, scratch, &ctn)
      if aargs.lead_tys.empty?
        ctn[recv, ep, env.enable_module_function]
      else
        aargs.lead_tys.each do |aarg|
          sym = get_sym("module_function", aarg, ep, scratch) or next
          meths = Type::Instance.new(recv).get_method(sym, scratch)
          meths.each do |mdef|
            scratch.add_singleton_method(recv, sym, mdef)
          end
        end
        ctn[recv, ep, env]
      end
    end

    def add_attr_reader(sym, cref, scratch)
      iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[0][1][1]
      scratch.add_iseq_method(cref.klass, sym, iseq_getter, cref)
    end

    def add_attr_writer(sym, cref, scratch)
      iseq_setter = ISeq.compile_str("def #{ sym }=(x); @#{ sym } = x; end").insns[0][1][1]
      scratch.add_iseq_method(cref.klass, :"#{ sym }=", iseq_setter, cref)
    end

    def module_attr_accessor(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_accessor", aarg, ep, scratch) or next
        cref = ep.ctx.cref
        add_attr_reader(sym, cref, scratch)
        add_attr_writer(sym, cref, scratch)
      end
      ctn[Type.nil, ep, env]
    end

    def module_attr_reader(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_reader", aarg, ep, scratch) or next
        cref = ep.ctx.cref
        add_attr_reader(sym, cref, scratch)
      end
      ctn[Type.nil, ep, env]
    end

    def module_attr_writer(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_writer", aarg, ep, scratch) or next
        cref = ep.ctx.cref
        add_attr_writer(sym, cref, scratch)
      end
      ctn[Type.nil, ep, env]
    end

    def kernel_p(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        scratch.reveal_type(ep, scratch.globalize_type(aarg, env, ep))
      end
      ctn[aargs.lead_tys.size == 1 ? aargs.lead_tys.first : Type.any, ep, env]
    end

    def array_aref(recv, mid, aargs, ep, env, scratch, &ctn)
      case aargs.lead_tys.size
      when 1
        idx = aargs.lead_tys.first
        if idx.is_a?(Type::Literal)
          idx = idx.lit
          if idx.is_a?(Range)
            ty = scratch.get_array_elem_type(env, ep, recv.id)
            base_ty = Type::Instance.new(Type::Builtin[:ary])
            ret_ty = Type::Array.new(Type::Array::Elements.new([], ty), base_ty)
            ctn[ret_ty, ep, env]
            return
          end
          raise NotImplementedError if !idx.is_a?(Integer)
        else
          idx = nil
        end
        ty = scratch.get_array_elem_type(env, ep, recv.id, idx)
        ctn[ty, ep, env]
      when 2
        ty = scratch.get_array_elem_type(env, ep, recv.id)
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        ret_ty = Type::Array.new(Type::Array::Elements.new([], ty), base_ty)
        ctn[ret_ty, ep, env]
      else
        ctn[Type.any, ep, env]
      end
    end

    def array_aset(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 2

      idx = aargs.lead_tys.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      ty = aargs.lead_tys.last

      env = scratch.update_container_elem_types(env, ep, recv.id) do |elems|
        elems.update(idx, ty)
      end

      ctn[ty, ep, env]
    end

    def array_ltlt(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1

      ty = aargs.lead_tys.first

      env = scratch.update_container_elem_types(env, ep, recv.id) do |elems|
        elems.append(ty)
      end

      ctn[recv, ep, env]
    end

    def array_each(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 0
      ty = scratch.get_array_elem_type(env, ep, recv.id)
      naargs = ActualArguments.new([ty], nil, nil, Type.nil)
      scratch.do_invoke_block(false, aargs.blk_ty, naargs, ep, env) do |_ret_ty, ep|
        ctn[recv, ep, scratch.return_envs[ep]] # XXX: refactor "scratch.return_envs"
      end
    end

    def array_map(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 0
      # TODO: get_array_elem_type does squash, but tuple part may be preserved
      if recv.is_a?(Type::LocalArray)
        ty = scratch.get_array_elem_type(env, ep, recv.id)
      else
        ty = Type.any
      end
      naargs = ActualArguments.new([ty], nil, nil, Type.nil)
      scratch.do_invoke_block(false, aargs.blk_ty, naargs, ep, env) do |ret_ty, ep|
        base_ty = Type::Instance.new(Type::Builtin[:ary])
        ret_ty = Type::Array.new(Type::Array::Elements.new([], ret_ty), base_ty)
        ctn[ret_ty, ep, scratch.return_envs[ep]] # XXX: refactor "scratch.return_envs"
      end
    end

    def array_plus(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      ary = aargs.lead_tys.first
      elems1 = scratch.get_array_elem_type(env, ep, recv.id)
      if ary.is_a?(Type::LocalArray)
        elems2 = scratch.get_array_elem_type(env, ep, ary.id)
        elems = Type::Array::Elements.new([], elems1.union(elems2))
        ty = Type::Array.new(elems, recv.base_type)
        ctn[ty, ep, env]
      else
        # warn??
        ctn[Type.any, ep, env]
      end
    end

    def array_pop(recv, mid, aargs, ep, env, scratch, &ctn)
      if aargs.lead_tys.size != 0
        ctn[Type.any, ep, env]
        return
      end

      ty = scratch.get_array_elem_type(env, ep, recv.id)
      ctn[ty, ep, env]
    end

    def array_include?(recv, mid, aargs, ep, env, scratch, &ctn)
      ctn[Type.bool, ep, env]
    end

    def hash_aref(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      key = aargs.lead_tys.first
      # XXX: recv may be a union
      recv.each_child do |recv|
        if recv.is_a?(Type::LocalHash)
          ty = scratch.get_hash_elem_type(env, ep, recv.id, key)
        else
          ty = Type.any
        end
        ctn[ty, ep, env]
      end
    end

    def hash_aset(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 2

      idx = aargs.lead_tys.first
      idx = scratch.globalize_type(idx, env, ep)
      ty = aargs.lead_tys.last

      unless recv.is_a?(Type::LocalHash)
        # to ignore: class OptionMap < Hash
        return ctn[ty, ep, env]
      end

      env = scratch.update_container_elem_types(env, ep, recv.id) do |elems|
        elems.update(idx, ty)
      end

      ctn[ty, ep, env]
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

    def kernel_require(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      feature = aargs.lead_tys.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        begin
          filetype, path = $LOAD_PATH.resolve_feature_path(feature)
          if filetype == :rb
            # TODO: if there is RBS file for the library, do not read the source code
            return file_load(path, ep, env, scratch, &ctn) if File.readable?(path)

            scratch.warn(ep, "failed to load: #{ path }")
          else
            scratch.warn(ep, "cannnot load a .so file: #{ path }")
          end
        rescue LoadError
          scratch.warn(ep, "failed to load: #{ path }")
        end
      else
        scratch.warn(ep, "require target cannot be identified statically")
      end

      result = Type::Instance.new(Type::Builtin[:true])
      ctn[result, ep, env]
    end

    def kernel_require_relative(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      feature = aargs.lead_tys.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        path = File.join(File.dirname(ep.ctx.iseq.path), feature) + ".rb" # XXX
        return file_load(path, ep, env, scratch, &ctn) if File.readable?(path)

        scratch.warn(ep, "failed to load: #{ path }")
      else
        scratch.warn(ep, "require target cannot be identified statically")
        feature = nil
      end

      result = Type::Instance.new(Type::Builtin[:true])
      ctn[result, ep, env]
    end
  end

  def self.setup_initial_global_env(scratch)
    klass_obj = scratch.new_class(nil, :Object, :__root__) # cbase, name, superclass
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
    klass_hash      = scratch.get_constant(klass_obj, :Hash)
    klass_proc      = scratch.get_constant(klass_obj, :Proc)
    klass_range     = scratch.get_constant(klass_obj, :Range)
    klass_regexp    = scratch.get_constant(klass_obj, :Regexp)
    klass_matchdata = scratch.get_constant(klass_obj, :MatchData)
    klass_class     = scratch.get_constant(klass_obj, :Class)
    klass_module    = scratch.get_constant(klass_obj, :Module)

    Type::Builtin[:vmcore]    = klass_vmcore
    Type::Builtin[:float]     = klass_float
    Type::Builtin[:sym]       = klass_sym
    Type::Builtin[:str]       = klass_str
    Type::Builtin[:hash]      = klass_hash
    Type::Builtin[:proc]      = klass_proc
    Type::Builtin[:range]     = klass_range
    Type::Builtin[:regexp]    = klass_regexp
    Type::Builtin[:matchdata] = klass_matchdata
    Type::Builtin[:class]     = klass_class
    Type::Builtin[:module]    = klass_module

    scratch.add_custom_method(klass_vmcore, :"core#set_method_alias", Builtin.method(:vmcore_set_method_alias))
    scratch.add_custom_method(klass_vmcore, :"core#undef_method", Builtin.method(:vmcore_undef_method))
    scratch.add_custom_method(klass_vmcore, :"core#hash_merge_kwd", Builtin.method(:vmcore_hash_merge_kwd))
    scratch.add_custom_method(klass_vmcore, :lambda, Builtin.method(:lambda))
    scratch.add_singleton_custom_method(klass_obj, :"new", Builtin.method(:object_new))
    scratch.add_singleton_custom_method(klass_obj, :"attr_accessor", Builtin.method(:module_attr_accessor))
    scratch.add_singleton_custom_method(klass_obj, :"attr_reader", Builtin.method(:module_attr_reader))
    scratch.add_singleton_custom_method(klass_obj, :"attr_writer", Builtin.method(:module_attr_writer))
    scratch.add_custom_method(klass_obj, :p, Builtin.method(:kernel_p))
    scratch.add_custom_method(klass_obj, :is_a?, Builtin.method(:object_is_a?))
    scratch.add_custom_method(klass_obj, :class, Builtin.method(:object_class))
    scratch.add_custom_method(klass_obj, :send, Builtin.method(:object_send))

    scratch.add_custom_method(klass_module, :include, Builtin.method(:module_include))
    scratch.add_custom_method(klass_module, :extend, Builtin.method(:module_extend))
    scratch.add_custom_method(klass_module, :module_function, Builtin.method(:module_module_function))

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

    scratch.add_custom_method(klass_hash, :[], Builtin.method(:hash_aref))
    scratch.add_custom_method(klass_hash, :[]=, Builtin.method(:hash_aset))

    i = -> t { Type::Instance.new(t) }

    scratch.add_typed_method(i[klass_obj], :==, FormalArguments.new([Type.any], [], nil, [], nil, nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_obj], :!=, FormalArguments.new([Type.any], [], nil, [], nil, nil, i[klass_nil]), Type.bool)
    scratch.add_typed_method(i[klass_obj], :initialize, FormalArguments.new([], [], nil, [], nil, nil, Type.any), Type.any)
    scratch.add_typed_method(i[klass_str], :to_s, FormalArguments.new([], [], nil, [], nil, nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_sym], :to_s, FormalArguments.new([], [], nil, [], nil, nil, i[klass_nil]), i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_sym, FormalArguments.new([], [], nil, [], nil, nil, i[klass_nil]), i[klass_sym])
    scratch.add_typed_method(i[klass_str], :+ , FormalArguments.new([i[klass_str]], [], nil, [], nil, nil, i[klass_nil]), i[klass_str])

    fargs1 = FormalArguments.new([i[klass_int]], [], nil, [], nil, nil, i[klass_nil])
    fargs2 = FormalArguments.new([i[klass_str]], [], nil, [], nil, nil, i[klass_nil])
    mdef = TypedMethodDef.new([[fargs1, i[klass_int]], [fargs2, i[klass_int]]])
    scratch.add_method(klass_obj, :Integer, mdef)

    scratch.add_custom_method(klass_obj, :require, Builtin.method(:kernel_require))
    scratch.add_custom_method(klass_obj, :require_relative, Builtin.method(:kernel_require_relative))
  end
end
