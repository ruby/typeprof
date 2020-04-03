module TypeProfiler
  module RubySignatureImporter
    module_function

    def path_to_klass(scratch, path)
      klass = Type::Builtin[:obj]
      path.each do |name|
        klass = scratch.get_constant(klass, name)
        raise if klass == Type.any
      end
      klass
    end

    CACHE = {}

    def import_ruby_signatures(scratch, feature)
      CACHE[feature] ||=
        begin
          file = File.join(__dir__, "../../rbsc/#{ feature }.rbsc")
          return unless File.readable?(file)
          Marshal.load(File.binread(file))
        end
      rbs_classes, rbs_constants = CACHE[feature]
      classes = []
      rbs_classes.each do |classpath, (superclass, included_modules, methods)|
        next if classpath == [:BasicObject]
        next if classpath == [:NilClass]
        if classpath != [:Object]
          name = classpath.last
          base_klass = path_to_klass(scratch, classpath[0..-2])
          superclass = path_to_klass(scratch, superclass) if superclass
          klass = scratch.get_constant(base_klass, name)
          if klass.is_a?(Type::Any)
            klass = scratch.new_class(base_klass, name, superclass)
            case classpath
            when [:NilClass] then Type::Builtin[:nil] = klass
            when [:Integer]  then Type::Builtin[:int] = klass
            when [:String]   then Type::Builtin[:str] = klass
            when [:Symbol]   then Type::Builtin[:sym] = klass
            when [:Array]    then Type::Builtin[:ary] = klass
            when [:Hash]     then Type::Builtin[:hash] = klass
            end
          end
        else
          klass = Type::Builtin[:obj]
        end
        classes << [klass, included_modules, methods]
      end

      classes.each do |klass, included_modules, methods|
        included_modules.each do |mod|
          mod = path_to_klass(scratch, mod)
          scratch.include_module(klass, mod, false)
        end
        methods.each do |(singleton, method_name), mdef|
          mdef = translate_typed_method_def(scratch, method_name, mdef)
          scratch.add_method(klass, method_name, singleton, mdef)
        end
      end

      rbs_constants.each do |classpath, value|
        base_klass = path_to_klass(scratch, classpath[0..-2])
        value = convert_type(scratch, value)
        scratch.add_constant(base_klass, classpath[-1], value)
      end

      true
    end

    def translate_typed_method_def(scratch, method_name, mdef)
      sig_rets = mdef.map do |lead_tys, opt_tys, req_kw_tys, opt_kw_tys, rest_kw_ty, blk, ret_ty|
        if blk
          blk = translate_typed_block(scratch, blk)
        else
          blk = Type::Instance.new(scratch.get_constant(Type::Builtin[:obj], :NilClass))
        end

        begin
          lead_tys = lead_tys.map {|ty| convert_type(scratch, ty) }
          opt_tys = opt_tys.map {|ty| convert_type(scratch, ty) }
          kw_tys = []
          req_kw_tys.each {|key, ty| kw_tys << [true, key, convert_type(scratch, ty)] }
          opt_kw_tys.each {|key, ty| kw_tys << [false, key, convert_type(scratch, ty)] }
          kw_rest_ty = convert_type(scratch, rest_kw_ty) if rest_kw_ty
          fargs = FormalArguments.new(lead_tys, opt_tys, nil, [], kw_tys, kw_rest_ty, blk)
          ret_ty = convert_type(scratch, ret_ty)
          [fargs, ret_ty]
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
      when :class
        path_to_klass(scratch, ty[1])
      when :instance
        begin
          Type::Instance.new(path_to_klass(scratch, ty[1]))
        rescue
          raise UnsupportedType
        end
      when :bool
        Type.bool
      when :any
        Type.any
      when :self
        Type::Self.new
      when :int
        Type::Instance.new(Type::Builtin[:int])
      when :str
        Type::Instance.new(Type::Builtin[:str])
      when :sym
        Type::Symbol.new(ty.last, Type::Instance.new(Type::Builtin[:sym]))
      when :nil
        Type.nil
      when :true
        Type::Instance.new(Type::Builtin[:true])
      when :false
        Type::Instance.new(Type::Builtin[:false])
      when :array
        _, lead_tys, rest_ty = ty
        lead_tys = lead_tys.map {|ty| convert_type(scratch, ty) }
        rest_ty = convert_type(scratch, rest_ty)
        Type::Array.new(Type::Array::Elements.new(lead_tys, rest_ty), Type::Instance.new(Type::Builtin[:ary]))
      when :hash
        _, *map_tys = ty
        Type.gen_hash do |h|
          map_tys.each do |k, v|
            k_ty = convert_type(scratch, k)
            v_ty = convert_type(scratch, v)
            h[k_ty] = v_ty
          end
        end
      when :union
        tys = ty[1].reject {|ty2| ty2[1] == [:BigDecimal] } # XXX
        Type::Union.new(Utils::Set[*tys.map {|ty2| convert_type(scratch, ty2) }], nil, nil) #  Array support
      when :optional
        Type.optional(convert_type(scratch, ty[1]))
      else
        pp ty
        raise NotImplementedError
      end
    end
  end
end
