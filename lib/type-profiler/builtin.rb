module TypeProfiler
  module Builtin
    module_function

    def vmcore_define_method(state, flags, recv, mid, args, blk, lenv, scratch)
      mid, iseq = args
      cref = lenv.ctx.cref
      sym = mid.lit
      raise "symbol expected" unless sym.is_a?(Symbol)
      scratch.add_iseq_method(cref.klass, sym, iseq.iseq, cref)
      lenv = lenv.push(mid)
      [State.new(lenv.next)]
    end

    def vmcore_define_singleton_method(state, flags, recv, mid, args, blk, lenv, scratch)
      recv_ty, mid, iseq = args
      cref = lenv.ctx.cref
      sym = mid.lit
      raise "symbol expected" unless sym.is_a?(Symbol)
      scratch.add_singleton_iseq_method(recv_ty, sym, iseq.iseq, cref)
      lenv = lenv.push(mid)
      [State.new(lenv.next)]
    end

    def vmcore_set_method_alias(state, flags, recv, mid, args, blk, lenv, scratch)
      klass, new_mid, old_mid = args
      new_sym = new_mid.lit
      raise "symbol expected" unless new_sym.is_a?(Symbol)
      old_sym = old_mid.lit
      raise "symbol expected" unless old_sym.is_a?(Symbol)
      scratch.alias_method(klass, new_sym, old_sym)
      lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      [State.new(lenv.next)]
    end

    def lambda(state, flags, recv, mid, args, blk, lenv, scratch)
      lenv = lenv.push(blk)
      [State.new(lenv.next)]
    end

    def proc_call(state, flags, recv, mid, args, blk, lenv, scratch)
      given_block = lenv.ctx.sig.blk_ty == recv
      return State.do_invoke_block(given_block, recv, args, blk, lenv, scratch)
    end

    def object_new(state, flags, recv, mid, args, blk, lenv, scratch)
      ty = Type::Instance.new(recv)
      meth = scratch.get_method(recv, :initialize)
      meth.do_send(state, 0, ty, :initialize, args, blk, lenv, scratch) do |ret_ty, lenv|
        nlenv = lenv.push(Type::Instance.new(recv)).next
        State.new(nlenv)
      end
    end

    def module_attr_accessor(state, flags, recv, mid, args, blk, lenv, scratch)
      args.each do |arg|
        sym = arg.lit
        cref = lenv.ctx.cref
        raise "symbol expected" unless sym.is_a?(Symbol)
        iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[2][1]
        iseq_setter = ISeq.compile_str("def #{ sym }=(x); @#{ sym } = x; end").insns[2][1]
        scratch.add_iseq_method(cref.klass, sym, iseq_getter, cref)
        scratch.add_iseq_method(cref.klass, :"#{ sym }=", iseq_setter, cref)
      end
      lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      [State.new(lenv.next)]
    end

    def module_attr_reader(state, flags, recv, mid, args, blk, lenv, scratch)
      args.each do |arg|
        sym = arg.lit
        cref = lenv.ctx.cref
        raise "symbol expected" unless sym.is_a?(Symbol)
        iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[2][1]
        scratch.add_iseq_method(cref.klass, sym, iseq_getter, cref)
      end
      lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      [State.new(lenv.next)]
    end

    def reveal_type(state, flags, recv, mid, args, blk, lenv, scratch)
      args.each do |arg|
        scratch.reveal_type(state, arg.strip_local_info(lenv).screen_name(scratch))
      end
      lenv = lenv.push(Type::Any.new)
      [State.new(lenv.next)] # should be fixed?
    end

    def array_aref(state, flags, recv, mid, args, blk, lenv, scratch)
      raise NotImplementedError if args.size != 1
      idx = args.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      # assumes that recv is LocalArray
      elems = lenv.get_array_elem_types(recv.id)
      if idx
        elem = elems[idx] || Type::Union.new(Type::Instance.new(Type::Builtin[:nil])) # HACK
      else
        elem = Type::Union.new(*elems.types)
      end
      return elem.types.map do |ty|
        nlenv = lenv.push(ty).next
        State.new(nlenv)
      end
    end

    def array_aset(state, flags, recv, mid, args, blk, lenv, scratch)
      raise NotImplementedError if args.size != 2
      idx = args.first
      if idx.is_a?(Type::Literal)
        idx = idx.lit
        raise NotImplementedError if !idx.is_a?(Integer)
      else
        idx = nil
      end

      ty = args.last
      lenv = lenv.update_array_elem_types(recv.id, idx, ty)
      lenv = lenv.push(ty).next
      return [State.new(lenv)]
    end

    def array_each(state, flags, recv, mid, args, blk, lenv, scratch)
      raise NotImplementedError if args.size != 0
      elems = lenv.get_array_elem_types(recv.id)
      elems = elems.types
      return elems.flat_map do |ty|
        blk_nil = Type::Instance.new(Type::Builtin[:nil])
        State.do_invoke_block(false, blk, [ty], blk_nil, lenv, scratch) do |ret_ty, lenv|
          nlenv = lenv.push(recv).next
          State.new(nlenv)
        end
      end + [State.new(lenv.push(recv).next)]
    end

    def array_plus(state, flags, recv, mid, args, blk, lenv, scratch)
      raise NotImplementedError if args.size != 1
      ary = args.first
      elems1 = lenv.get_array_elem_types(recv.id)
      if ary.is_a?(Type::LocalArray)
        elems2 = lenv.get_array_elem_types(ary.id)
        elems = Type::Array::Seq.new(Type::Union.new(*(elems1.types | elems2.types)))
        id = 0
        lenv, ty, = lenv.deploy_array_type(recv.base_type, elems, id)
        return [State.new(lenv.push(ty).next)]
      else
        # warn??
        return [State.new(lenv.push(Type::Any.new).next)]
      end
    end

    def array_pop(state, flags, recv, mid, args, blk, lenv, scratch)
      if args.size != 0
        return [State.new(lenv.push(Type::Any.new).next)]
      end

      elems = lenv.get_array_elem_types(recv.id)
      return elems.types.map do |ty|
        State.new(lenv.push(ty).next)
      end
    end

    def require_relative(state, flags, recv, mid, args, blk, lenv, scratch)
      raise NotImplementedError if args.size != 1
      feature = args.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        path = File.join(File.dirname(state.lenv.ctx.iseq.path), feature) + ".rb" # XXX
        if File.readable?(path)
          iseq = TypeProfiler::ISeq.compile(path)
          nstate = TypeProfiler.starting_state(iseq)

          scratch.add_callsite!(nstate.lenv.ctx, lenv) do |_ret_ty, lenv|
            result = Type::Literal.new(true, Type::Instance.new(Type::Builtin[:bool]))
            nlenv = lenv.push(result).next
            State.new(nlenv)
          end

          return [nstate]
        else
          scratch.warn(state, "failed to read: #{ path }")
        end

        feature
      else
        scratch.warn(state, "require target cannot be identified statically")
        feature = nil
      end

      result = Type::Literal.new(true, Type::Instance.new(Type::Builtin[:bool]))
      lenv = lenv.push(result).next
      return [State.new(lenv)]
    end
  end

  def self.setup_initial_global_env(scratch)
    klass_obj = scratch.new_class(nil, :Object, nil) # cbase, name, superclass
    scratch.add_constant(klass_obj, "Object", klass_obj)

    klass_vmcore    = scratch.new_class(klass_obj, :VMCore, klass_obj) # cbase, name, superclass
    klass_int       = scratch.new_class(klass_obj, :Integer, klass_obj)
    klass_sym       = scratch.new_class(klass_obj, :Symbol, klass_obj)
    klass_str       = scratch.new_class(klass_obj, :String, klass_obj)
    klass_bool      = scratch.new_class(klass_obj, :Boolean, klass_obj) # ???
    klass_nil       = scratch.new_class(klass_obj, :NilClass, klass_obj)
    klass_ary       = scratch.new_class(klass_obj, :Array, klass_obj)
    klass_proc      = scratch.new_class(klass_obj, :Proc, klass_obj)
    klass_range     = scratch.new_class(klass_obj, :Range, klass_obj)
    klass_regexp    = scratch.new_class(klass_obj, :Regexp, klass_obj)
    klass_matchdata = scratch.new_class(klass_obj, :MatchData, klass_obj)

    Type::Builtin[:vmcore]    = klass_vmcore
    Type::Builtin[:obj]       = klass_obj
    Type::Builtin[:int]       = klass_int
    Type::Builtin[:sym]       = klass_sym
    Type::Builtin[:bool]      = klass_bool
    Type::Builtin[:str]       = klass_str
    Type::Builtin[:nil]       = klass_nil
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
    scratch.add_custom_method(klass_proc, :[], Builtin.method(:proc_call))
    scratch.add_custom_method(klass_proc, :call, Builtin.method(:proc_call))
    scratch.add_custom_method(klass_ary, :[], Builtin.method(:array_aref))
    scratch.add_custom_method(klass_ary, :[]=, Builtin.method(:array_aset))
    scratch.add_custom_method(klass_ary, :each, Builtin.method(:array_each))
    scratch.add_custom_method(klass_ary, :+, Builtin.method(:array_plus))
    scratch.add_custom_method(klass_ary, :pop, Builtin.method(:array_pop))

    i = -> t { Type::Instance.new(t) }

    scratch.add_typed_method(i[klass_obj], :==, [Type::Any.new], i[klass_nil], i[klass_bool])
    scratch.add_typed_method(i[klass_obj], :!=, [Type::Any.new], i[klass_nil], i[klass_bool])
    scratch.add_typed_method(i[klass_obj], :initialize, [], i[klass_nil], i[klass_nil])
    scratch.add_typed_method(i[klass_int], :< , [i[klass_int]], i[klass_nil], i[klass_bool])
    scratch.add_typed_method(i[klass_int], :<=, [i[klass_int]], i[klass_nil], i[klass_bool])
    scratch.add_typed_method(i[klass_int], :>=, [i[klass_int]], i[klass_nil], i[klass_bool])
    scratch.add_typed_method(i[klass_int], :> , [i[klass_int]], i[klass_nil], i[klass_bool])
    scratch.add_typed_method(i[klass_int], :+ , [i[klass_int]], i[klass_nil], i[klass_int])
    scratch.add_typed_method(i[klass_int], :- , [i[klass_int]], i[klass_nil], i[klass_int])
    int_times_blk = Type::TypedProc.new([i[klass_int]], Type::Any.new, Type::Builtin[:proc])
    scratch.add_typed_method(i[klass_int], :times, [], int_times_blk, i[klass_int])
    scratch.add_typed_method(i[klass_int], :to_s, [], i[klass_nil], i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_s, [], i[klass_nil], i[klass_str])
    scratch.add_typed_method(i[klass_sym], :to_s, [], i[klass_nil], i[klass_str])
    scratch.add_typed_method(i[klass_str], :to_sym, [], i[klass_nil], i[klass_sym])

    sig1 = Signature.new(i[klass_obj], false, :Integer, [i[klass_int]], i[klass_nil])
    sig2 = Signature.new(i[klass_obj], false, :Integer, [i[klass_str]], i[klass_nil])
    mdef = TypedMethodDef.new([[sig1, i[klass_int]], [sig2, i[klass_int]]])
    scratch.add_method(klass_obj, :Integer, mdef)

    scratch.add_custom_method(klass_obj, :require_relative, Builtin.method(:require_relative))
  end
end
