#!/usr/bin/env ruby

require "ruby/signature"
require "json"

class TypeProfiler
  class RubySignatureReader
    include Ruby::Signature

    def initialize(library = nil, builtin = nil)
      loader = EnvironmentLoader.new(stdlib_root: Pathname("vendor/sigs/stdlib/"))
      @env = Environment.new()
      loader.add(library: library) if library != "builtin"
      loader.load(env: @env)

      @dump = [import_rbs_classes, import_rbs_constants]

      remove_builtin_definitions(builtin) if builtin
    end

    attr_reader :dump

    # constant_name = [Symbol]
    #
    # { constant_name => type }
    def import_rbs_constants
      constants = {}
      @env.each_constant do |name, decl|
        #constants[name] = decl
        klass = name.namespace.path + [name.name]
        constants[klass] = convert_type(decl.type)
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
      @env.each_decl do |name, decl|
        if name.kind == :class
          next if name.name == :Object && name.namespace == Namespace.root
          if decl.is_a?(AST::Declarations::Class)
            #next unless decl.super_class
            class2super[name] = superclass = decl.super_class&.name || BuiltinNames::Object.name
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
            decl = @env.find_class(name)
            if decl.is_a?(AST::Declarations::Class)
              until BuiltinNames::Object.name == decl.name.absolute!
                super_class = decl.super_class
                break unless super_class
                decl = @env.find_class(super_class.name.absolute!)
                queue << [:visit, decl.name.absolute!]
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
        methods = []

        if [:Object, :Array, :Numeric, :Integer, :Float, :Math, :Range, :TrueClass, :FalseClass, :Kernel].include?(type_name.name) || true
          [@env.find_class(type_name), *@env.find_extensions(type_name)].each do |decl|
            raise NotImplementedError if decl.is_a?(AST::Declarations::Interface)

            methods = {}
            decl.members.each do |member|
              case member
              when AST::Members::MethodDefinition
                name = member.name

                # ad-hoc filter
                if member.instance?
                  case type_name.name
                  when :Object
                    next if name == :class
                    next if name == :send
                    next if name == :is_a?
                    next if name == :respond_to?
                  when :Array
                    next unless [:empty?, :size].include?(name)
                  when :Hash
                    next unless [:empty?, :size].include?(name)
                  when :Module
                    next if name == :include
                    next if name == :module_function
                  when :Proc
                    next if name == :call || name == :[]
                  end
                end

                method_types = member.types.map do |method_type|
                  case method_type
                  when MethodType
                    method_type.map_type do |type|
                      @env.absolute_type(type, namespace: type_name.to_namespace) do |ty|
                        ty.name
                      end
                    end
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
                name = @env.absolute_type_name(member.name, namespace: type_name.namespace)
                mod = name.namespace.path + [name.name]
                included_modules << mod
              when AST::Members::InstanceVariable
                raise NotImplementedError
              when AST::Members::ClassVariable
                raise NotImplementedError
              when AST::Members::Public, AST::Members::Private
              else
                p member
              end
            end
          end
        end

        result[klass] = [superclass, included_modules, methods]
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
          [lead_tys, opt_tys, rest_ty, req_kw_tys, opt_kw_tys, rest_kw_ty, blk, ret_ty]
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
      when Ruby::Signature::Types::ClassSingleton
        klass = ty.name.namespace.path + [ty.name.name]
        [:class, klass]
      when Ruby::Signature::Types::ClassInstance
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
      when Ruby::Signature::Types::Bases::Bool
        [:bool]
      when Ruby::Signature::Types::Bases::Any
        [:any]
      when Ruby::Signature::Types::Bases::Void
        [:any]
      when Ruby::Signature::Types::Bases::Self
        [:self]
      when Ruby::Signature::Types::Bases::Nil
        [:nil]
      when Ruby::Signature::Types::Bases::Bottom
        [:union, []]
      when Ruby::Signature::Types::Variable
        [:any] # temporal
      when Ruby::Signature::Types::Tuple
        tys = ty.types.map {|ty2| convert_type(ty2) }
        [:array, tys, [:union, []]]
      when Ruby::Signature::Types::Literal
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
      when Ruby::Signature::Types::Literal
      when Ruby::Signature::Types::Alias
        ty = @env.absolute_type(@env.find_alias(ty.name).type, namespace: ty.name.namespace)
        convert_type(ty)
      when Ruby::Signature::Types::Union
        [:union, ty.types.map {|ty2| convert_type(ty2) }]
      when Ruby::Signature::Types::Optional
        [:optional, convert_type(ty.type)]
      when Ruby::Signature::Types::Interface
        [:any]
      else
        pp ty
        raise NotImplementedError
      end
    end

    def remove_builtin_definitions(builtin)
      builtin[0].each do |name, (_super_class, included_modules, methods)|
        _, new_included_modules, new_methods = @dump[0][name]
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
