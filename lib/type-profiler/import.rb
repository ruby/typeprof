module TypeProfiler
  module RubySignatureImporter
    module_function

    def path_to_klass(scratch, path)
      klass = Type::Builtin[:obj]
      path.each do |name|
        klass = scratch.get_constant(klass, name)
        raise if klass == Type::Any.new
      end
      klass
    end

    def import_ruby_signatures(scratch)
      classes = []
      STDLIB_SIGS.each do |klass, superclass, methods, singleton_methods|
        next if klass == [:BasicObject]
        next if klass == [:Object]
        next if klass == [:NilClass]
        name = klass.last
        klass = path_to_klass(scratch, klass[0..-2])
        superclass = path_to_klass(scratch, superclass) if superclass
        klass = scratch.new_class(klass, name, superclass)
        classes << [klass, methods, singleton_methods]
      end

      classes.each do |klass, methods, singleton_methods|
        methods.each do |method_name, mdef|
          mdef = translate_typed_method_def(scratch, false, method_name, mdef, klass)
          scratch.add_method(klass, method_name, mdef)
        end
        singleton_methods.each do |method_name, mdef|
          mdef = translate_typed_method_def(scratch, true, method_name, mdef, klass)
          scratch.add_singleton_method(klass, method_name, mdef)
        end
      end
    end

    def translate_typed_method_def(scratch, singleton, method_name, mdef, klass)
      sig_rets = mdef.map do |lead_tys, opt_tys, blk, ret_ty|
        if blk
          blk = translate_typed_block(scratch, blk)
        else
          blk = Type::Instance.new(scratch.get_constant(Type::Builtin[:obj], :NilClass))
        end

        begin
          lead_tys = lead_tys.map {|ty| convert_type(scratch, ty) }
          opt_tys = opt_tys.map {|ty| convert_type(scratch, ty) }
          fargs = FormalArguments.new(lead_tys, opt_tys, nil, [], nil, blk)
          sig = Signature.new(Type::Instance.new(klass), singleton, method_name, fargs)
          ret_ty = convert_type(scratch, ret_ty)
          [sig, ret_ty]
        rescue UnsupportedType
          nil
        end
      end.compact

      TypedMethodDef.new(sig_rets)
    end

    def translate_typed_block(scratch, blk)
      lead_tys, ret_ty = blk
      lead_tys = lead_tys.map {|ty| convert_type(scratch, ty) }
      ret_ty = convert_type(scratch, ret_ty)
      Type::TypedProc.new(lead_tys, ret_ty, Type::Builtin[:proc])
    end

    class UnsupportedType < StandardError
    end

    def convert_type(scratch, ty)
      case ty.first
      when :instance
        begin
          Type::Instance.new(path_to_klass(scratch, ty[1]))
        rescue
          raise UnsupportedType
        end
      when :bool
        Type::Instance.new(Type::Builtin[:bool])
      when :any
        Type::Any.new
      when :union
        Type::Sum.new(Utils::Set[*ty[1].map {|ty2| convert_type(scratch, ty2) }])
      when :optional
        Type::Sum.new(Utils::Set[Type::Instance.new(Type::Builtin[:nil]), convert_type(scratch, ty[1])])
      else
        pp ty
        raise NotImplementedError
      end
    end
  end
end
