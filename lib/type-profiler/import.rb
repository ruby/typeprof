require "ruby/signature"

module TypeProfiler
  module RubySignatureImporter
    include Ruby::Signature
    module_function


    def tsort(classes, visited = {})
      visited
    end

    def import_ruby_signatures(scratch)
      loader = EnvironmentLoader.new()
      env = Environment.new()
      loader.load(env: env)
      builder = DefinitionBuilder.new(env: env)

      class2super = {}
      env.each_decl do |name, decl|
        if name.kind == :class
          next if name.name == :Object && name.namespace == Namespace.root
          if decl.is_a?(AST::Declarations::Class)
            next unless decl.super_class
            class2super[name] = decl.super_class.name
          else
            class2super[name] = nil
          end
        end
      end

      classes = []

      # topological sort
      queue = class2super.keys.map {|name| [:visit, name] }
      visited = {}
      until queue.empty?
        #p queue.map {|ev, name| [ev, name.to_s] }
        event, name = queue.pop
        case event
        when :visit
          if !visited[name]
            visited[name] = true
            queue << [:new, name]
            instance = builder.build_instance(name)
            instance.ancestors.each do |parent|
              if env.find_class(parent.name).is_a?(AST::Declarations::Class)
                queue << [:visit, parent.name]
              end
            end
            if !name.namespace.empty?
              queue << [:visit, name.namespace.to_type_name]
            end
          end
        when :new
          next if name.name == :BasicObject && name.namespace == Namespace.root
          next if name.name == :Object && name.namespace == Namespace.root
          next if name.name == :NilClass && name.namespace == Namespace.root
          super_class_name = class2super[name]
          klass = Type::Builtin[:obj]
          name.namespace.path.each do |name|
            klass = scratch.get_constant(klass, name)
            raise if klass == Type::Any.new
          end
          if super_class_name
            superclass = Type::Builtin[:obj]
            super_class_name.namespace.path.each do |name|
              superclass = scratch.get_constant(superclass, name)
            end
            superclass = scratch.get_constant(superclass, super_class_name.name)
            #puts
            #pp [:super, super_class_name.name]
            #pp superclass
          else
            superclass = nil
          end
          #p [klass, name.name, superclass]
          klass = scratch.new_class(klass, name.name, superclass)
          classes << [name, klass]
        end
      end

      classes.each do |type_name, klass|
        # XXX
        next unless [:Numeric, :Integer, :Float, :Math].include?(type_name.name)

        builder.build_instance(type_name).methods.each do |name, method|
          # XXX
          case type_name.name
          when :Numeric
            next unless [:step].include?(name)
          when :Integer
            next unless [:+, :-, :*, :/, :<, :>, :-@, :<<, :>>, :|, :&, :to_f].include?(name)
          when :Float
            next unless [:+, :-, :*, :/, :<, :>, :-@].include?(name)
          when :Math
            next
          end

          mdef = translate_typed_method_def(scratch, name, method, klass)
          scratch.add_method(klass, name, mdef)
        end

        builder.build_singleton(type_name).methods.each do |name, method|
          case type_name.name
          when :Numeric, :Integer, :Float
            next
          when :Math
            next unless [:sqrt, :sin, :cos].include?(name)
          end

          mdef = translate_typed_method_def(scratch, name, method, klass)
          scratch.add_singleton_method(klass, name, mdef)
        end
      end
    end

    def translate_typed_method_def(scratch, name, rs_method, klass)
      sig_rets = rs_method.method_types.map do |type|
        raise NotImplementedError unless type.type.optional_keywords.empty?
        raise NotImplementedError unless type.type.required_keywords.empty?
        raise NotImplementedError if type.type.rest_keywords

        if type.block
          blk = translate_typed_block(scratch, type.block)
        else
          blk = Type::Instance.new(scratch.get_constant(Type::Builtin[:obj], :NilClass))
        end

        singleton = false
        begin
          lead_tys = type.type.required_positionals.map do |type|
            convert_type(scratch, type.type)
          end
          opt_tys = type.type.optional_positionals.map do |type|
            convert_type(scratch, type.type)
          end
          fargs = FormalArguments.new(lead_tys, opt_tys, nil, [], nil, blk)
          sig = Signature.new(Type::Instance.new(klass), singleton, name, fargs)
          ret_ty = convert_type(scratch, type.type.return_type)
          [sig, ret_ty]
        rescue UnsupportedType
          nil
        end
      end.compact

      TypedMethodDef.new(sig_rets)
    end

    def translate_typed_block(scratch, rs_block)
      type = rs_block.type
      raise NotImplementedError unless type.optional_keywords.empty?
      raise NotImplementedError unless type.required_keywords.empty?
      raise NotImplementedError unless type.optional_positionals.empty?
      raise NotImplementedError if type.rest_keywords
      lead_tys = type.required_positionals.map do |type|
        convert_type(scratch, type.type)
      end
      ret_ty = convert_type(scratch, type.return_type)
      Type::TypedProc.new(lead_tys, ret_ty, Type::Builtin[:proc])
    end

    class UnsupportedType < StandardError
    end

    def convert_type(scratch, ty)
      case ty
      when Ruby::Signature::Types::ClassInstance
        klass = scratch.get_constant(Type::Builtin[:obj], ty.name.name)
        if klass != Type::Any.new
          Type::Instance.new(klass)
        else
          raise UnsupportedType
        end
      when Ruby::Signature::Types::Bases::Bool
        Type::Instance.new(Type::Builtin[:bool])
      when Ruby::Signature::Types::Bases::Any
        Type::Any.new
      when Ruby::Signature::Types::Union
        Type::Sum.new(Utils::Set[*ty.types.map {|ty2| convert_type(scratch, ty2) }])
      when Ruby::Signature::Types::Optional
        Type::Sum.new(Utils::Set[Type::Instance.new(Type::Builtin[:nil]), convert_type(scratch, ty.type)])
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
