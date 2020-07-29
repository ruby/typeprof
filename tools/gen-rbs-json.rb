#!/usr/bin/env ruby

require "rbs"
require "json"

# factory = RBS::Factory.new()
# entry = env.class_decls[factory.type_name("::Object")]

class TypeProfiler
  class RubySignatureReader
    include RBS

    def initialize(library = nil, builtin = nil)
      loader = EnvironmentLoader.new#(stdlib_root: Pathname("vendor/sigs/stdlib/"))
      loader.add(library: library) if library != "builtin"
      @env = Environment.from_loader(loader).resolve_type_names

      @dump = [import_rbs_classes, import_rbs_constants]

      remove_builtin_definitions(builtin) if builtin
    end

    attr_reader :dump

    # constant_name = [Symbol]
    #
    # { constant_name => type }
    def import_rbs_constants
      constants = {}
      @env.constant_decls.each do |name, decl|
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
      @env.class_decls.each do |name, decl|
        next if name.name == :Object && name.namespace == Namespace.root
        decl.decls.each do |decl|
          decl = decl.decl
          if decl.is_a?(AST::Declarations::Class)
            #next unless decl.super_class
            class2super[name] ||= decl.super_class&.name || BuiltinNames::Object.name
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
            decl = @env.class_decls[name]
            decl.decls.each do |decl|
              decl = decl.decl
              next if decl.is_a?(AST::Declarations::Module)
              until BuiltinNames::Object.name == decl.name
                super_class = decl.super_class
                break unless super_class
                decls = @env.class_decls[super_class.name].decls
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
        included_modules = []
        methods = {}
        type_params = nil

        if [:Object, :Array, :Numeric, :Integer, :Float, :Math, :Range, :TrueClass, :FalseClass, :Kernel].include?(type_name.name) || true
          @env.class_decls[type_name].decls.each do |decl|
            decl = decl.decl
            raise NotImplementedError if decl.is_a?(AST::Declarations::Interface)
            type_params2 = decl.type_params.params.map {|param| [param.name, param.variance] }
            if type_params
              raise if type_params != type_params2
            else
              type_params = type_params2
            end

            decl.members.each do |member|
              case member
              when AST::Members::MethodDefinition
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
                  when :Hash
                    @array_special_tyvar_handling = true
                    next if name == :[]
                    next if name == :[]=
                    next if name == :to_proc
                    #next unless [:empty?, :size].include?(name)
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
                  when MethodType
                    method_type
                  when :super
                    raise NotImplementedError
                  end
                end

                method_def = translate_typed_method_def(method_types)
                methods[[false, name]] = method_def if member.instance?
                methods[[true, name]] = method_def if member.singleton?
              when AST::Members::AttrReader, AST::Members::AttrAccessor, AST::Members::AttrWriter
                raise NotImplementedError
              when AST::Members::Alias
                if member.instance?
                  method_def = methods[[false, member.old_name]]
                  methods[[false, member.new_name]] = method_def if method_def
                end
                if member.singleton?
                  method_def = methods[[true, member.old_name]]
                  methods[[true, member.new_name]] = method_def if method_def
                end
              when AST::Members::Include
                name = member.name
                mod = name.namespace.path + [name.name]
                included_modules << mod
              when AST::Members::InstanceVariable
                raise NotImplementedError
              when AST::Members::ClassVariable
                raise NotImplementedError
              when AST::Members::Public, AST::Members::Private
              when AST::Declarations::Constant
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
          [:array, [], convert_type(ty.args.first)]
        when [:Hash]
          raise if ty.args.size != 2
          key, val = ty.args
          [:hash, [convert_type(key), convert_type(val)]]
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
        [:array, tys, [:union, []]]
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
        ty = @env.alias_decls[ty.name].decl.type
        convert_type(ty)
      when RBS::Types::Union
        [:union, ty.types.map {|ty2| begin convert_type(ty2); rescue UnsupportedType; end }.compact]
      when RBS::Types::Optional
        [:optional, convert_type(ty.type)]
      when RBS::Types::Interface
        raise UnsupportedType if ty.to_s == "::_ToStr" # XXX
        raise UnsupportedType if ty.to_s == "::_ToInt" # XXX
        if ty.to_s == "::_ToAry[U]" # XXX
          return [:array, [], [:var, :U]]
        end
        [:any]
      else
        pp ty
        raise NotImplementedError
      end
    end

    def remove_builtin_definitions(builtin)
      builtin[0].each do |name, (_type_params, _super_class, included_modules, methods)|
        _, _, new_included_modules, new_methods = @dump[0][name]
        if new_included_modules
          new_included_modules -= included_modules
          @dump[0][name][1] = new_included_modules
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
        if @dump[0][name][1].empty? && new_methods.empty?
          @dump[0].delete(name)
        end
      end

      builtin[1].each do |name, type|
        new_type = @dump[1][name]
        if new_type
          if type == new_type
            @dump[1].delete(name)
          end
        end
      end
    end
  end
end

builtin = nil
%w(builtin pathname).each do |lib|
  target = File.join(__dir__, "../rbsc/#{ lib }.rbsc")
  stdlib = TypeProfiler::RubySignatureReader.new(lib, builtin)
  builtin ||= stdlib.dump
  File.binwrite(target, Marshal.dump(stdlib.dump))
end
