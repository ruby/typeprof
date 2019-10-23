require "ruby/signature"

module TypeProfiler
  module RubySignatureImporter
    include Ruby::Signature
    module_function

    def import_ruby_signatures(scratch)
      loader = EnvironmentLoader.new()
      env = Environment.new()
      loader.load(env: env)
      builder = DefinitionBuilder.new(env: env)

      classes = []
      env.each_decl do |name, decl|
        if name.kind == :class
          next if name.name == :Object && name.namespace == Namespace.root

          klass = Type::Builtin[:obj]
          name.namespace.path.each do |name|
            klass = scratch.get_constant(klass, name)
            raise if klass == Type::Any.new
          end
          klass = scratch.new_class(klass, name.name, nil) # XXX: superclass
          classes << [name, klass]
        end
      end

      klass_nil = scratch.get_constant(Type::Builtin[:obj], :NilClass)

      classes.each do |name, klass|
        # XXX
        next if name.name != :Integer

        type_name = TypeName.new(name: :Integer, namespace: Namespace.root)
        builder.build_instance(type_name).methods.each do |name, method|
          # XXX
          next if name != :+

          sig_rets = method.method_types.map do |type|
            raise NotImplementedError unless type.type.optional_keywords.empty?
            raise NotImplementedError unless type.type.optional_positionals.empty?
            raise NotImplementedError unless type.type.required_keywords.empty?
            raise NotImplementedError if type.type.rest_keywords

            singleton = false
            lead_tys = type.type.required_positionals.map do |type|
              Type::Instance.new(convert_type(scratch, type.type))
            end
            fargs = FormalArguments.new(lead_tys, nil, nil, nil, nil, Type::Instance.new(klass_nil))
            sig = Signature.new(Type::Instance.new(klass), singleton, name, fargs)
            ret_ty = Type::Instance.new(convert_type(scratch, type.type.return_type))
            [sig, ret_ty]
          end

          mdef = TypedMethodDef.new(sig_rets)
          scratch.add_method(klass, name, mdef)
        end
      end
    end

    def convert_type(scratch, ty)
      case ty
      when Ruby::Signature::Types::ClassInstance
        scratch.get_constant(Type::Builtin[:obj], ty.name.name)
      else
        pp ty
        raise NotImplementedError
      end
    end

    def convert_name_to_klass(scratch, name)
      namespace = name.namespace
      raise NotImplementedError if namespace.absolute?
      path = namespace.path
      raise NotImplementedError if name.kind != :class
      path += [name.name]

      # TODO: support path
      klass = Type::Builtin[:obj]
      path.each do |name|
        klass = scratch.get_constant(klass, name)
        p [:klass, klass]
      end
      return klass
    end
  end
end
