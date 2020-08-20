require "rbs"

module TypeProfiler
  class RBSReader
    def initialize
      @env, @builtin_env_dump = RBSReader.builtin_env
    end

    def self.builtin_env
      return @builtin_env.dup, @builtin_env_dump if @builtin_env

      loader = RBS::EnvironmentLoader.new
      env = RBS::Environment.new
      decls = loader.load(env: env)
      @builtin_env = env
      @builtin_env_dump = RBS2JSON.new(env, decls).dump
      return env.dup, @builtin_env_dump
    end

    def load_builtin
      @builtin_env_dump
    end

    def load_library(lib)
      loader = RBS::EnvironmentLoader.new
      loader.no_builtin!
      loader.add(library: lib)
      new_decls = loader.load(env: @env)
      RBS2JSON.new(@env, new_decls).dump
    end
  end

  class RBS2JSON
    def initialize(env, new_decls)
      @all_env = env.resolve_type_names

      resolver = RBS::TypeNameResolver.from_env(env)
      @current_env = RBS::Environment.new()

      new_decls.each do |decl,|
        @current_env << env.resolve_declaration(resolver, decl, outer: [], prefix: RBS::Namespace.root)
      end
    end

    def dump
      [import_rbs_classes, import_rbs_constants]
    end

    # constant_name = [Symbol]
    #
    # { constant_name => type }
    def import_rbs_constants
      constants = {}
      @current_env.constant_decls.each do |name, decl|
        #constants[name] = decl
        klass = name.namespace.path + [name.name]
        constants[klass] = convert_type(decl.decl.type)
      end
      constants
    end

    # class_name = [Symbol]
    # method_name = [singleton: true|false, Symbol}
    # method_def = [...]
    #
    # { class_name =>
    #   [ super_class: class_name,
    #     included_modules: [class_name],
    #     methods: { method_name => [method_def] },
    #   ]
    # }
    def import_rbs_classes
      class2super = {}
      # XXX: @env.each_global {|a| p a }
      @current_env.class_decls.each do |name, decl|
        next if name.name == :Object && name.namespace == RBS::Namespace.root
        decl.decls.each do |decl|
          decl = decl.decl
          if decl.is_a?(RBS::AST::Declarations::Class)
            #next unless decl.super_class
            class2super[name] ||= decl.super_class&.name || RBS::BuiltinNames::Object.name
          else
            class2super[name] ||= nil
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
            decl = @all_env.class_decls[name]
            decl.decls.each do |decl|
              decl = decl.decl
              next if decl.is_a?(RBS::AST::Declarations::Module)
              until RBS::BuiltinNames::Object.name == decl.name
                super_class = decl.super_class
                break unless super_class
                decls = @all_env.class_decls[super_class.name].decls
                raise if decls.size >= 2 # no need to check
                decl = decls.first.decl
                queue << [:visit, decl.name]
              end
            end
            if !name.namespace.empty?
              queue << [:visit, name.namespace.to_type_name]
            end
          end
        when :new
          super_class_name = class2super[name]
          klass = name.namespace.path + [name.name]
          if super_class_name
            superclass = super_class_name.namespace.path + [super_class_name.name]
          else
            superclass = nil
          end
          classes << [name, klass, superclass]
        end
      end

      result = {}
      classes.each do |type_name, klass, superclass|
        next unless @current_env.class_decls[type_name]

        included_modules = []
        methods = {}
        type_params = nil

        if [:Object, :Array, :Numeric, :Integer, :Float, :Math, :Range, :TrueClass, :FalseClass, :Kernel].include?(type_name.name) || true
          @current_env.class_decls[type_name].decls.each do |decl|
            decl = decl.decl
            raise NotImplementedError if decl.is_a?(RBS::AST::Declarations::Interface)
            type_params2 = decl.type_params.params.map {|param| [param.name, param.variance] }
            if type_params
              raise if type_params != type_params2
            else
              type_params = type_params2
            end

            decl.members.each do |member|
              case member
              when RBS::AST::Members::MethodDefinition
                name = member.name

                # ad-hoc filter
                @array_special_tyvar_handling = false
                if member.instance?
                  case type_name.name
                  when :Object
                    next if name == :class
                    next if name == :send
                    next if name == :is_a?
                    next if name == :respond_to?
                  when :Array
                    @array_special_tyvar_handling = true
                    next if name == :[]
                    next if name == :[]=
                    next if name == :pop
                  when :Enumerable
                    @array_special_tyvar_handling = true
                  when :Enumerator
                    @array_special_tyvar_handling = true
                  when :Hash
                    @array_special_tyvar_handling = true
                    next if name == :[]
                    next if name == :[]=
                    next if name == :to_proc
                    #next unless [:empty?, :size].include?(name)
                  when :Struct
                    next if name == :initialize
                  when :Module
                    next if name == :include
                    next if name == :module_function
                  when :Proc
                    next if name == :call || name == :[]
                  when :Kernel
                    next if name == :Array
                  end
                end
                if member.singleton?
                  case type_name.name
                  when :Array
                    @array_special_tyvar_handling = true
                  end
                end

                method_types = member.types.map do |method_type|
                  case method_type
                  when RBS::MethodType
                    method_type
                  when :super
                    raise NotImplementedError
                  end
                end

                method_def = translate_typed_method_def(method_types)
                methods[[false, name]] = method_def if member.instance?
                methods[[true, name]] = method_def if member.singleton?
              when RBS::AST::Members::AttrReader, RBS::AST::Members::AttrAccessor, RBS::AST::Members::AttrWriter
                raise NotImplementedError
              when RBS::AST::Members::Alias
                if member.instance?
                  method_def = methods[[false, member.old_name]]
                  methods[[false, member.new_name]] = method_def if method_def
                end
                if member.singleton?
                  method_def = methods[[true, member.old_name]]
                  methods[[true, member.new_name]] = method_def if method_def
                end
              when RBS::AST::Members::Include
                name = member.name
                mod = name.namespace.path + [name.name]
                included_modules << mod
              when RBS::AST::Members::InstanceVariable
                raise NotImplementedError
              when RBS::AST::Members::ClassVariable
                raise NotImplementedError
              when RBS::AST::Members::Public, RBS::AST::Members::Private
              when RBS::AST::Declarations::Constant
              else
                p member
              end
            end
          end
        end

        result[klass] = [type_params, superclass, included_modules, methods]
      end.compact

      result
    end

    def translate_typed_method_def(rs_method_types)
      rs_method_types.map do |type|
        if type.block
          blk = translate_typed_block(type.block)
        else
          blk = nil
        end
        type_params = type.type_params

        singleton = false
        begin
          lead_tys = type.type.required_positionals.map do |type|
            convert_type(type.type)
          end
          opt_tys = type.type.optional_positionals.map do |type|
            convert_type(type.type)
          end
          rest_ty = type.type.rest_positionals
          rest_ty = convert_type(rest_ty.type) if rest_ty
          opt_kw_tys = type.type.optional_keywords.to_h do |key, type|
            [key, convert_type(type.type)]
          end
          req_kw_tys = type.type.required_keywords.to_h do |key, type|
            [key, convert_type(type.type)]
          end
          rest_kw_ty = type.type.rest_keywords
          raise NotImplementedError if rest_kw_ty

          ret_ty = convert_type(type.type.return_type)
          [type_params, lead_tys, opt_tys, rest_ty, req_kw_tys, opt_kw_tys, rest_kw_ty, blk, ret_ty]
        rescue UnsupportedType
          nil
        end
      end.compact
    end

    def translate_typed_block(rs_block)
      type = rs_block.type
      raise NotImplementedError unless type.optional_keywords.empty?
      raise NotImplementedError unless type.required_keywords.empty?
      raise NotImplementedError unless type.optional_positionals.empty?
      raise NotImplementedError if type.rest_keywords
      lead_tys = type.required_positionals.map do |type|
        convert_type(type.type)
      end
      ret_ty = convert_type(type.return_type)
      [lead_tys, ret_ty]
    end

    class UnsupportedType < StandardError
    end

    def convert_type(ty)
      case ty
      when RBS::Types::ClassSingleton
        klass = ty.name.namespace.path + [ty.name.name]
        [:class, klass]
      when RBS::Types::ClassInstance
        klass = ty.name.namespace.path + [ty.name.name]
        case klass
        when [:Array]
          raise if ty.args.size != 1
          [:array, :Array, [], convert_type(ty.args.first)]
        when [:Hash]
          raise if ty.args.size != 2
          key, val = ty.args
          [:hash, :Hash, [convert_type(key), convert_type(val)]]
        when [:Enumerator]
          raise if ty.args.size != 2
          [:array, :Enumerator, [], convert_type(ty.args.first)]
        else
          [:instance, klass]
        end
      when RBS::Types::Bases::Bool
        [:bool]
      when RBS::Types::Bases::Any
        [:any]
      when RBS::Types::Bases::Void
        [:any]
      when RBS::Types::Bases::Self
        [:self]
      when RBS::Types::Bases::Nil
        [:nil]
      when RBS::Types::Bases::Bottom
        [:union, []]
      when RBS::Types::Variable
        if @array_special_tyvar_handling
          [:var, ty.name]
        else
          [:any]
        end
      when RBS::Types::Tuple
        tys = ty.types.map {|ty2| convert_type(ty2) }
        [:array, :Array, tys, [:union, []]]
      when RBS::Types::Literal
        case ty.literal
        when Integer
          [:int]
        when String
          [:str]
        when true
          [:true]
        when false
          [:false]
        when Symbol
          [:sym, ty.literal]
        else
          p ty.literal
          raise NotImplementedError
        end
      when RBS::Types::Literal
      when RBS::Types::Alias
        ty = @all_env.alias_decls[ty.name].decl.type
        convert_type(ty)
      when RBS::Types::Union
        [:union, ty.types.map {|ty2| begin convert_type(ty2); rescue UnsupportedType; end }.compact]
      when RBS::Types::Optional
        [:optional, convert_type(ty.type)]
      when RBS::Types::Interface
        raise UnsupportedType if ty.to_s == "::_ToStr" # XXX
        raise UnsupportedType if ty.to_s == "::_ToInt" # XXX
        if ty.to_s == "::_ToAry[U]" # XXX
          return [:array, :Array, [], [:var, :U]]
        end
        [:any]
      else
        pp ty
        raise NotImplementedError
      end
    end

    def remove_builtin_definitions(dump, builtin)
      builtin[0].each do |name, (_type_params, _super_class, included_modules, methods)|
        _, _, new_included_modules, new_methods = dump[0][name]
        if new_included_modules
          new_included_modules -= included_modules
          dump[0][name][1] = new_included_modules
        end
        if new_methods
          methods.each do |method_name, method_defs|
            new_method_defs = new_methods[method_name]
            if new_method_defs
              new_method_defs -= method_defs
              if new_method_defs.empty?
                new_methods.delete(method_name)
              else
                new_methods[method_name] = new_method_defs
              end
            end
          end
        end
        if dump[0][name][1].empty? && new_methods.empty?
          dump[0].delete(name)
        end
      end

      builtin[1].each do |name, type|
        new_type = dump[1][name]
        if new_type
          if type == new_type
            dump[1].delete(name)
          end
        end
      end

      dump
    end
  end

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

    def import_builtin(scratch)
      import_ruby_signature(scratch, scratch.rbs_reader.load_builtin)
    end

    def import_library(scratch, feature)
      # need cache?
      import_ruby_signature(scratch, scratch.rbs_reader.load_library(feature))
    end

    def import_ruby_signature(scratch, dump)
      rbs_classes, rbs_constants = dump
      classes = []
      rbs_classes.each do |classpath, (type_params, superclass, included_modules, methods)|
        next if classpath == [:BasicObject]
        next if classpath == [:NilClass]
        if classpath != [:Object]
          name = classpath.last
          base_klass = path_to_klass(scratch, classpath[0..-2])
          superclass = path_to_klass(scratch, superclass) if superclass
          klass = scratch.get_constant(base_klass, name)
          if klass.is_a?(Type::Any)
            klass = scratch.new_class(base_klass, name, type_params, superclass)
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
      sig_rets = mdef.map do |type_params, lead_tys, opt_tys, rest_ty, req_kw_tys, opt_kw_tys, rest_kw_ty, blk, ret_ty|
        if blk
          blk = translate_typed_block(scratch, blk)
        else
          blk = Type::Instance.new(scratch.get_constant(Type::Builtin[:obj], :NilClass))
        end

        begin
          lead_tys = lead_tys.map {|ty| convert_type(scratch, ty) }
          opt_tys = opt_tys.map {|ty| convert_type(scratch, ty) }
          rest_ty = convert_type(scratch, rest_ty) if rest_ty
          kw_tys = []
          req_kw_tys.each {|key, ty| kw_tys << [true, key, convert_type(scratch, ty)] }
          opt_kw_tys.each {|key, ty| kw_tys << [false, key, convert_type(scratch, ty)] }
          kw_rest_ty = convert_type(scratch, rest_kw_ty) if rest_kw_ty
          fargs = FormalArguments.new(lead_tys, opt_tys, rest_ty, [], kw_tys, kw_rest_ty, blk)
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
        Type::Var.new(:self)
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
        _, klass, lead_tys, rest_ty = ty
        lead_tys = lead_tys.map {|ty| convert_type(scratch, ty) }
        rest_ty = convert_type(scratch, rest_ty)
        base_type = Type::Instance.new(scratch.get_constant(Type::Builtin[:obj], klass))
        Type::Array.new(Type::Array::Elements.new(lead_tys, rest_ty), base_type)
      when :hash
        _, _klass, (k, v) = ty
        Type.gen_hash do |h|
          k_ty = convert_type(scratch, k)
          v_ty = convert_type(scratch, v)
          h[k_ty] = v_ty
        end
      when :union
        tys = ty[1].reject {|ty2| ty2[1] == [:BigDecimal] } # XXX
        Type::Union.new(Utils::Set[*tys.map {|ty2| convert_type(scratch, ty2) }], nil, nil) #  Array support
      when :optional
        Type.optional(convert_type(scratch, ty[1]))
      when :var
        Type::Var.new(ty[1]) # Currently, only for Array#* : (int | string) -> Array[Elem]
      else
        pp ty
        raise NotImplementedError
      end
    end
  end
end
