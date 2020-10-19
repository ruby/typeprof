module TypeProf
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

    def object_s_new(recv, mid, aargs, ep, env, scratch, &ctn)
      ty = Type::Instance.new(recv)
      meths = scratch.get_method(recv, false, :initialize)
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

    def object_respond_to?(recv, mid, aargs, ep, env, scratch, &ctn)
      raise unless aargs.lead_tys.size != 0
      sym = get_sym("respond_to?", aargs.lead_tys[0], ep, scratch)
      if sym
        if recv.get_method(sym, scratch)
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
      found = false
      mid_ty.each_child do |mid|
        if mid.is_a?(Type::Symbol)
          found = true
          mid = mid.sym
          scratch.do_send(recv, mid, aargs, ep, env, &ctn)
        end
      end
      unless found
        ctn[Type.any, ep, env]
      end
    end

    def object_instance_eval(recv, mid, aargs, ep, env, scratch, &ctn)
      if aargs.lead_tys.size >= 1
        scratch.warn(ep, "instance_eval with arguments are ignored")
        ctn[type.any, ep, env]
        return
      end
      naargs = ActualArguments.new([recv], Type.nil, nil, Type.nil)
      given_block = env.static_env.blk_ty == recv
      scratch.do_invoke_block(given_block, aargs.blk_ty, naargs, ep, env, replace_recv_ty: recv) do |_ret_ty, ep|
        ctn[recv, ep, scratch.return_envs[ep]]
      end
    end

    def module_include(recv, mid, aargs, ep, env, scratch, &ctn)
      arg = aargs.lead_tys[0]
      scratch.include_module(recv, arg, ep.ctx.iseq.absolute_path)
      ctn[recv, ep, env]
    end

    def module_extend(recv, mid, aargs, ep, env, scratch, &ctn)
      arg = aargs.lead_tys[0]
      arg.each_child do |arg|
        if arg.is_a?(Type::Class)
          scratch.extend_module(recv, arg, ep.ctx.iseq.absolute_path)
        end
      end
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
            scratch.add_method(recv, sym, true, mdef)
          end
        end
        ctn[recv, ep, env]
      end
    end

    def module_attr_accessor(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_accessor", aarg, ep, scratch) or next
        cref = ep.ctx.cref
        scratch.add_attr_method(cref.klass, ep.ctx.iseq.absolute_path, sym, :"@#{ sym }", :accessor)
      end
      ctn[Type.nil, ep, env]
    end

    def module_attr_reader(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_reader", aarg, ep, scratch) or next
        cref = ep.ctx.cref
        scratch.add_attr_method(cref.klass, ep.ctx.iseq.absolute_path, sym, :"@#{ sym }", :reader)
      end
      ctn[Type.nil, ep, env]
    end

    def module_attr_writer(recv, mid, aargs, ep, env, scratch, &ctn)
      aargs.lead_tys.each do |aarg|
        sym = get_sym("attr_writer", aarg, ep, scratch) or next
        cref = ep.ctx.cref
        scratch.add_attr_method(cref.klass, ep.ctx.iseq.absolute_path, sym, :"@#{ sym }", :writer)
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
      return ctn[Type.any, ep, env] unless recv.is_a?(Type::LocalArray)

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
          idx = nil if !idx.is_a?(Integer)
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
      return ctn[Type.any, ep, env] unless recv.is_a?(Type::LocalArray)

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

    def array_pop(recv, mid, aargs, ep, env, scratch, &ctn)
      return ctn[Type.any, ep, env] unless recv.is_a?(Type::LocalArray)

      if aargs.lead_tys.size != 0
        ctn[Type.any, ep, env]
        return
      end

      ty = scratch.get_array_elem_type(env, ep, recv.id)
      ctn[ty, ep, env]
    end

    def hash_aref(recv, mid, aargs, ep, env, scratch, &ctn)
      return ctn[Type.any, ep, env] unless recv.is_a?(Type::LocalHash)

      if aargs.lead_tys.size != 1
        ctn[Type.any, ep, env]
        return
      end
      idx = aargs.lead_tys.first
      #idx = scratch.globalize_type(idx, env, ep)
      # XXX: recv may be a union
      recv.each_child do |recv|
        if recv.is_a?(Type::LocalHash)
          ty = scratch.get_hash_elem_type(env, ep, recv.id, idx)
        else
          ty = Type.any
        end
        ctn[ty, ep, env]
      end
    end

    def hash_aset(recv, mid, aargs, ep, env, scratch, &ctn)
      return ctn[Type.any, ep, env] unless recv.is_a?(Type::LocalHash)

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

    def struct_initialize(recv, mid, aargs, ep, env, scratch, &ctn)
      recv = Type::Instance.new(recv)
      scratch.get_instance_variable(recv, :_members, ep, env) do |ty, nenv|
        ty = scratch.globalize_type(ty, nenv, ep)
        ty.elems.lead_tys.zip(aargs.lead_tys) do |sym, ty|
          ty ||= Type.nil
          scratch.set_instance_variable(recv, sym.sym, ty, ep, env)
        end
      end
      #scratch.set_instance_variable(recv, , ty, ep, env)
      ctn[recv, ep, env]
    end

    def struct_i_new(recv, mid, aargs, ep, env, scratch, &ctn)
      struct_klass = recv
      while struct_klass.superclass != Type::Builtin[:struct]
        struct_klass = struct_klass.superclass
      end
      if struct_klass.superclass != Type::Builtin[:struct]
        ctn[Type.any, ep, env]
        return
      end
      if struct_klass != recv
        scratch.get_instance_variable(Type::Instance.new(struct_klass), :_members, ep, env) do |ty, nenv|
          ty = scratch.globalize_type(ty, nenv, ep)
          scratch.set_instance_variable(Type::Instance.new(recv), :_members, ty, ep, env)
        end
      end
      meths = scratch.get_method(recv, false, :initialize)
      meths.flat_map do |meth|
        meth.do_send(recv, :initialize, aargs, ep, env, scratch) do |ret_ty, ep, env|
          ctn[Type::Instance.new(recv), ep, env]
        end
      end
    end

    def struct_s_new(recv, mid, aargs, ep, env, scratch, &ctn)
      # TODO: keyword_init

      fields = aargs.lead_tys.map {|ty| get_sym("Struct.new", ty, ep, scratch) }.compact
      struct_klass = scratch.new_struct(ep)

      scratch.set_singleton_custom_method(struct_klass, :new, Builtin.method(:struct_i_new))
      scratch.set_singleton_custom_method(struct_klass, :[], Builtin.method(:struct_i_new))
      fields.each do |field|
        scratch.add_attr_method(struct_klass, ep.ctx.iseq.absolute_path, field, field, :accessor)
      end
      fields = fields.map {|field| Type::Symbol.new(field, Type::Instance.new(Type::Builtin[:sym])) }
      base_ty = Type::Instance.new(Type::Builtin[:ary])
      fields = Type::Array.new(Type::Array::Elements.new(fields), base_ty)
      scratch.set_instance_variable(Type::Instance.new(struct_klass), :_members, fields, ep, env)
      #set_singleton_custom_method(struct_klass, :members, Builtin.method(:...))

      ctn[struct_klass, ep, env]
    end

    def file_load(path, ep, env, scratch, &ctn)
      iseq = ISeq.compile(path)
      callee_ep, callee_env = CLI.starting_state(iseq)
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
          if scratch.loaded_features[feature]
            result = Type::Instance.new(Type::Builtin[:false])
            return ctn[result, ep, env]
          end
          scratch.loaded_features[feature] = true

          # XXX: dynamic RBS load is really needed??  Another idea:
          #
          # * RBS should be loaded in advance of analysis
          # * require "some_gem/foo" should be ignored
          # * require "app/foo" should always load .rb file (in this case, app/foo.rb)
          if Import.import_library(scratch, feature)
            result = Type::Instance.new(Type::Builtin[:true])
            return ctn[result, ep, env]
          end

          begin
            gem feature
          rescue Gem::MissingSpecError, Gem::LoadError
          end
          filetype, path = $LOAD_PATH.resolve_feature_path(feature)
          if filetype == :rb
            # TODO: if there is RBS file for the library, do not read the source code
            return file_load(path, ep, env, scratch, &ctn) if File.readable?(path)

            scratch.warn(ep, "failed to load: #{ path }")
          else
            scratch.warn(ep, "cannot load a .so file: #{ path }")
          end
        rescue LoadError
          scratch.warn(ep, "failed to require: #{ feature }")
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

        if scratch.loaded_features[feature]
          result = Type::Instance.new(Type::Builtin[:false])
          return ctn[result, ep, env]
        end
        scratch.loaded_features[feature] = true

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

    def kernel_Array(recv, mid, aargs, ep, env, scratch, &ctn)
      raise NotImplementedError if aargs.lead_tys.size != 1
      ty = aargs.lead_tys.first
      ty = scratch.globalize_type(ty, env, ep)
      all_ty = Type.bot
      ty.each_child_global do |ty|
        if ty.is_a?(Type::Array)
          all_ty = all_ty.union(ty)
        else
          base_ty = Type::Instance.new(Type::Builtin[:ary])
          ret_ty = Type::Array.new(Type::Array::Elements.new([ty]), base_ty)
          all_ty = all_ty.union(ret_ty)
        end
      end
      ctn[all_ty, ep, env]
    end

    def self.setup_initial_global_env(scratch)
      klass_basic_obj = scratch.new_class(nil, :BasicObject, [], :__root__) # cbase, name, superclass
      klass_obj = scratch.new_class(nil, :Object, [], klass_basic_obj)
      scratch.add_constant(klass_obj, "Object", klass_obj)
      scratch.add_constant(klass_obj, "BasicObject", klass_basic_obj)

      Type::Builtin[:basic_obj] = klass_basic_obj
      Type::Builtin[:obj]   = klass_obj

      Import.import_builtin(scratch)

      Type::Builtin[:vmcore]    = scratch.new_class(klass_obj, :VMCore, [], klass_obj)
      Type::Builtin[:int]       = scratch.get_constant(klass_obj, :Integer)
      Type::Builtin[:float]     = scratch.get_constant(klass_obj, :Float)
      Type::Builtin[:rational]  = scratch.get_constant(klass_obj, :Rational)
      Type::Builtin[:sym]       = scratch.get_constant(klass_obj, :Symbol)
      Type::Builtin[:str]       = scratch.get_constant(klass_obj, :String)
      Type::Builtin[:struct]    = scratch.get_constant(klass_obj, :Struct)
      Type::Builtin[:ary]       = scratch.get_constant(klass_obj, :Array)
      Type::Builtin[:hash]      = scratch.get_constant(klass_obj, :Hash)
      Type::Builtin[:io]        = scratch.get_constant(klass_obj, :IO)
      Type::Builtin[:proc]      = scratch.get_constant(klass_obj, :Proc)
      Type::Builtin[:range]     = scratch.get_constant(klass_obj, :Range)
      Type::Builtin[:regexp]    = scratch.get_constant(klass_obj, :Regexp)
      Type::Builtin[:matchdata] = scratch.get_constant(klass_obj, :MatchData)
      Type::Builtin[:class]     = scratch.get_constant(klass_obj, :Class)
      Type::Builtin[:module]    = scratch.get_constant(klass_obj, :Module)
      Type::Builtin[:exc]       = scratch.get_constant(klass_obj, :Exception)

      klass_vmcore = Type::Builtin[:vmcore]
      klass_ary    = Type::Builtin[:ary]
      klass_hash   = Type::Builtin[:hash]
      klass_struct = Type::Builtin[:struct]
      klass_proc   = Type::Builtin[:proc]
      klass_module = Type::Builtin[:module]

      scratch.set_custom_method(klass_vmcore, :"core#set_method_alias", Builtin.method(:vmcore_set_method_alias))
      scratch.set_custom_method(klass_vmcore, :"core#undef_method", Builtin.method(:vmcore_undef_method))
      scratch.set_custom_method(klass_vmcore, :"core#hash_merge_kwd", Builtin.method(:vmcore_hash_merge_kwd))
      scratch.set_custom_method(klass_vmcore, :lambda, Builtin.method(:lambda))
      scratch.set_singleton_custom_method(klass_obj, :"new", Builtin.method(:object_s_new))
      scratch.set_singleton_custom_method(klass_obj, :"attr_accessor", Builtin.method(:module_attr_accessor))
      scratch.set_singleton_custom_method(klass_obj, :"attr_reader", Builtin.method(:module_attr_reader))
      scratch.set_singleton_custom_method(klass_obj, :"attr_writer", Builtin.method(:module_attr_writer))
      scratch.set_custom_method(klass_obj, :p, Builtin.method(:kernel_p))
      scratch.set_custom_method(klass_obj, :is_a?, Builtin.method(:object_is_a?))
      scratch.set_custom_method(klass_obj, :respond_to?, Builtin.method(:object_respond_to?))
      scratch.set_custom_method(klass_obj, :class, Builtin.method(:object_class))
      scratch.set_custom_method(klass_obj, :send, Builtin.method(:object_send))
      scratch.set_custom_method(klass_obj, :instance_eval, Builtin.method(:object_instance_eval))

      scratch.set_custom_method(klass_module, :include, Builtin.method(:module_include))
      scratch.set_custom_method(klass_module, :extend, Builtin.method(:module_extend))
      scratch.set_custom_method(klass_module, :module_function, Builtin.method(:module_module_function))

      scratch.set_custom_method(klass_proc, :[], Builtin.method(:proc_call))
      scratch.set_custom_method(klass_proc, :call, Builtin.method(:proc_call))

      scratch.set_custom_method(klass_ary, :[], Builtin.method(:array_aref))
      scratch.set_custom_method(klass_ary, :[]=, Builtin.method(:array_aset))
      scratch.set_custom_method(klass_ary, :pop, Builtin.method(:array_pop))

      scratch.set_custom_method(klass_hash, :[], Builtin.method(:hash_aref))
      scratch.set_custom_method(klass_hash, :[]=, Builtin.method(:hash_aset))

      scratch.set_custom_method(klass_struct, :initialize, Builtin.method(:struct_initialize))
      scratch.set_singleton_custom_method(klass_struct, :new, Builtin.method(:struct_s_new))

      scratch.set_custom_method(klass_obj, :require, Builtin.method(:kernel_require))
      scratch.set_custom_method(klass_obj, :require_relative, Builtin.method(:kernel_require_relative))
      scratch.set_custom_method(klass_obj, :Array, Builtin.method(:kernel_Array))

      fargs, ret_ty = FormalArguments.new([], [], nil, [], nil, nil, Type.any), Type.any
      scratch.add_method(klass_obj, :initialize, false, TypedMethodDef.new([[fargs, ret_ty]], nil))
    end
  end
end
