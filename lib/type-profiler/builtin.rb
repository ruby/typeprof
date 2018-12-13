module TypeProfiler
  module Builtin
    module_function

    def vmcore_define_method(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      mid, iseq = args
      cref = lenv.ctx.cref
      sym = mid.lit
      raise "symbol expected" unless sym.is_a?(Symbol)
      genv = genv.add_iseq_method(cref.klass, sym, iseq.iseq, cref)
      lenv = lenv.push(mid)
      [State.new(lenv.next, genv)]
    end

    def vmcore_define_singleton_method(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      recv_ty, mid, iseq = args
      cref = lenv.ctx.cref
      sym = mid.lit
      raise "symbol expected" unless sym.is_a?(Symbol)
      genv = genv.add_singleton_iseq_method(recv_ty, sym, iseq.iseq, cref)
      lenv = lenv.push(mid)
      [State.new(lenv.next, genv)]
    end

    def vmcore_set_method_alias(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      klass, new_mid, old_mid = args
      new_sym = new_mid.lit
      raise "symbol expected" unless new_sym.is_a?(Symbol)
      old_sym = old_mid.lit
      raise "symbol expected" unless old_sym.is_a?(Symbol)
      genv = genv.alias_method(klass, new_sym, old_sym)
      lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      [State.new(lenv.next, genv)]
    end

    def lambda(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      lenv = lenv.push(blk)
      [State.new(lenv.next, genv)]
    end

    def proc_call(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      given_block = lenv.ctx.sig.blk_ty == recv
      return State.do_invoke_block(given_block, recv, args, blk, lenv, genv, scratch)
    end

    def object_new(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      ty = Type::Instance.new(recv)
      meth = genv.get_method(recv, :initialize)
      return meth.do_send(state, 0, ty, :initialize, args, blk, lenv, genv, scratch) do |ret_ty, lenv, genv|
        nlenv = lenv.push(Type::Instance.new(recv)).next
        State.new(nlenv, genv)
      end
    end

    def module_attr_accessor(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      args.each do |arg|
        sym = arg.lit
        cref = lenv.ctx.cref
        raise "symbol expected" unless sym.is_a?(Symbol)
        iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[2][1]
        iseq_setter = ISeq.compile_str("def #{ sym }=(x); @#{ sym } = x; end").insns[2][1]
        genv = genv.add_iseq_method(cref.klass, sym, iseq_getter, cref)
        genv = genv.add_iseq_method(cref.klass, :"#{ sym }=", iseq_setter, cref)
      end
      lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      [State.new(lenv.next, genv)]
    end

    def module_attr_reader(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      args.each do |arg|
        sym = arg.lit
        cref = lenv.ctx.cref
        raise "symbol expected" unless sym.is_a?(Symbol)
        iseq_getter = ISeq.compile_str("def #{ sym }(); @#{ sym }; end").insns[2][1]
        genv = genv.add_iseq_method(cref.klass, sym, iseq_getter, cref)
      end
      lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      [State.new(lenv.next, genv)]
    end

    def array_aref(state, flags, recv, mid, args, blk, lenv, genv, scratch)
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
        elem = elems[idx] || [Type::Instance.new(Type::Builtin[:nil])]
      else
        elem = elems.flatten(1).uniq
      end
      return elem.map do |ty|
        nlenv = lenv.push(ty).next
        State.new(nlenv, genv)
      end
    end

    def array_aset(state, flags, recv, mid, args, blk, lenv, genv, scratch)
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
      return [State.new(lenv, genv)]
    end

    def require_relative(state, flags, recv, mid, args, blk, lenv, genv, scratch)
      raise NotImplementedError if args.size != 1
      feature = args.first
      if feature.is_a?(Type::Literal)
        feature = feature.lit

        path = File.join(File.dirname(state.lenv.ctx.iseq.path), feature) + ".rb" # XXX
        if File.readable?(path)
          iseq = TypeProfiler::ISeq.compile(path)
          nstate = TypeProfiler.starting_state(iseq, genv)

          scratch.add_callsite!(nstate.lenv.ctx, lenv, genv) do |_ret_ty, lenv, genv|
            result = Type::Literal.new(true, Type::Instance.new(Type::Builtin[:bool]))
            nlenv = lenv.push(result).next
            State.new(nlenv, genv)
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
      return [State.new(lenv, genv)]
    end
  end

  def self.setup_initial_global_env
    klass_obj = Type::Class.new(0)
    class_def_obj = ClassDef.new("Object", nil, { :Object => klass_obj }, {}, {})
    genv = GlobalEnv.new([class_def_obj])

    genv, klass_vmcore = genv.new_class(klass_obj, :VMCore, klass_obj)
    genv, klass_int  = genv.new_class(klass_obj, :Integer, klass_obj)
    genv, klass_sym  = genv.new_class(klass_obj, :Symbol, klass_obj)
    genv, klass_str  = genv.new_class(klass_obj, :String, klass_obj)
    genv, klass_bool = genv.new_class(klass_obj, :Boolean, klass_obj)
    genv, klass_nil  = genv.new_class(klass_obj, :NilClass, klass_obj)
    genv, klass_ary  = genv.new_class(klass_obj, :Array, klass_obj)
    genv, klass_proc = genv.new_class(klass_obj, :Proc, klass_obj)
    genv, klass_regexp    = genv.new_class(klass_obj, :Regexp, klass_obj)
    genv, klass_matchdata = genv.new_class(klass_obj, :MatchData, klass_obj)

    Type::Builtin[:vmcore] = klass_vmcore
    Type::Builtin[:obj]  = klass_obj
    Type::Builtin[:int]  = klass_int
    Type::Builtin[:sym]  = klass_sym
    Type::Builtin[:bool] = klass_bool
    Type::Builtin[:str]  = klass_str
    Type::Builtin[:nil]  = klass_nil
    Type::Builtin[:ary]  = klass_ary
    Type::Builtin[:proc] = klass_proc
    Type::Builtin[:regexp]    = klass_regexp
    Type::Builtin[:matchdata] = klass_matchdata

    genv = genv.add_custom_method(klass_vmcore, :"core#define_method", Builtin.method(:vmcore_define_method))
    genv = genv.add_custom_method(klass_vmcore, :"core#define_singleton_method", Builtin.method(:vmcore_define_singleton_method))
    genv = genv.add_custom_method(klass_vmcore, :"core#set_method_alias", Builtin.method(:vmcore_set_method_alias))
    genv = genv.add_custom_method(klass_vmcore, :lambda, Builtin.method(:lambda))
    genv = genv.add_singleton_custom_method(klass_obj, :"new", Builtin.method(:object_new))
    genv = genv.add_singleton_custom_method(klass_obj, :"attr_accessor", Builtin.method(:module_attr_accessor))
    genv = genv.add_singleton_custom_method(klass_obj, :"attr_reader", Builtin.method(:module_attr_reader))
    genv = genv.add_custom_method(klass_proc, :[], Builtin.method(:proc_call))
    genv = genv.add_custom_method(klass_proc, :call, Builtin.method(:proc_call))
    genv = genv.add_custom_method(klass_ary, :[], Builtin.method(:array_aref))
    genv = genv.add_custom_method(klass_ary, :[]=, Builtin.method(:array_aset))

    i = -> t { Type::Instance.new(t) }

    genv = genv.add_typed_method(i[klass_obj], :==, [Type::Any.new], i[klass_nil], i[klass_bool])
    genv = genv.add_typed_method(i[klass_obj], :!=, [Type::Any.new], i[klass_nil], i[klass_bool])
    genv = genv.add_typed_method(i[klass_obj], :initialize, [], i[klass_nil], i[klass_nil])
    genv = genv.add_typed_method(i[klass_int], :< , [i[klass_int]], i[klass_nil], i[klass_bool])
    genv = genv.add_typed_method(i[klass_int], :<=, [i[klass_int]], i[klass_nil], i[klass_bool])
    genv = genv.add_typed_method(i[klass_int], :>=, [i[klass_int]], i[klass_nil], i[klass_bool])
    genv = genv.add_typed_method(i[klass_int], :> , [i[klass_int]], i[klass_nil], i[klass_bool])
    genv = genv.add_typed_method(i[klass_int], :+ , [i[klass_int]], i[klass_nil], i[klass_int])
    genv = genv.add_typed_method(i[klass_int], :- , [i[klass_int]], i[klass_nil], i[klass_int])
    int_times_blk = Type::TypedProc.new([i[klass_int]], Type::Any.new, Type::Builtin[:proc])
    genv = genv.add_typed_method(i[klass_int], :times, [], int_times_blk, i[klass_int])
    genv = genv.add_typed_method(i[klass_int], :to_s, [], i[klass_nil], i[klass_str])
    genv = genv.add_typed_method(i[klass_str], :to_s, [], i[klass_nil], i[klass_str])
    genv = genv.add_typed_method(i[klass_sym], :to_s, [], i[klass_nil], i[klass_str])
    genv = genv.add_typed_method(i[klass_str], :to_sym, [], i[klass_nil], i[klass_sym])

    sig1 = Signature.new(i[klass_obj], false, :Integer, [i[klass_int]], i[klass_nil])
    sig2 = Signature.new(i[klass_obj], false, :Integer, [i[klass_str]], i[klass_nil])
    mdef = TypedMethodDef.new([[sig1, i[klass_int]], [sig2, i[klass_int]]])
    genv = genv.add_method(klass_obj, :Integer, mdef)

    genv = genv.add_custom_method(klass_obj, :require_relative, Builtin.method(:require_relative))

    genv
  end
end
