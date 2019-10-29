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

      classes.each do |type_name, klass|
        # XXX
        next unless [:Integer, :Float, :Math].include?(type_name.name)

        builder.build_instance(type_name).methods.each do |name, method|
          # XXX
          case type_name.name
          when :Integer
            next unless [:+, :to_f].include?(name)
          when :Float
            next unless [:+, :-, :*, :/, :<, :>, :-@].include?(name)
          when :Math
            next
          end

          mdef = translate_typed_method_def(scratch, method, klass, klass_nil)
          scratch.add_method(klass, name, mdef)
        end

        builder.build_singleton(type_name).methods.each do |name, method|
          case type_name.name
          when :Integer, :Float
            next
          when :Math
            next unless [:sqrt, :sin, :cos].include?(name)
          end

          mdef = translate_typed_method_def(scratch, method, klass, klass_nil)
          scratch.add_singleton_method(klass, name, mdef)
        end
      end
    end

    def translate_typed_method_def(scratch, rs_method, klass, klass_nil)
      sig_rets = rs_method.method_types.map do |type|
        raise NotImplementedError unless type.type.optional_keywords.empty?
        raise NotImplementedError unless type.type.optional_positionals.empty?
        raise NotImplementedError unless type.type.required_keywords.empty?
        raise NotImplementedError if type.type.rest_keywords

        singleton = false
        lead_tys = type.type.required_positionals.map do |type|
          convert_type(scratch, type.type)
        end
        fargs = FormalArguments.new(lead_tys, nil, nil, nil, nil, Type::Instance.new(klass_nil))
        sig = Signature.new(Type::Instance.new(klass), singleton, name, fargs)
        ret_ty = convert_type(scratch, type.type.return_type)
        [sig, ret_ty]
      end

      TypedMethodDef.new(sig_rets)
    end

    def convert_type(scratch, ty)
      case ty
      when Ruby::Signature::Types::ClassInstance
        Type::Instance.new(scratch.get_constant(Type::Builtin[:obj], ty.name.name))
      when Ruby::Signature::Types::Bases::Bool
        Type::Instance.new(Type::Builtin[:bool])
      when Ruby::Signature::Types::Union
        Type::Sum.new(Utils::Set[*ty.types.map {|ty2| convert_type(scratch, ty2) }])
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
