#!/usr/bin/env ruby

require "ruby/signature"
require "json"

class TypeProfiler
  class RubySignatureReader
    include Ruby::Signature

    def initialize
      loader = EnvironmentLoader.new(stdlib_root: Pathname("sigs/stdlib/"))
      @env = Environment.new()
      loader.load(env: @env)

      @dump = import_ruby_signatures
    end

    attr_reader :dump

    def import_ruby_signatures
      class2super = {}
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

      classes = classes.map do |type_name, klass, superclass|
        included_modules = []
        methods = []
        singleton_methods = []

        if [:Object, :Array, :Numeric, :Integer, :Float, :Math, :Range, :TrueClass, :FalseClass, :Kernel].include?(type_name.name)
          decl = @env.find_class(type_name)

          case decl
          when AST::Declarations::Extension, AST::Declarations::Interface
            raise NotImplementedError
          when AST::Declarations::Class, AST::Declarations::Module
            methods = []
            singleton_methods = []
            decl.members.each do |member|
              case member
              when AST::Members::MethodDefinition
                name = member.name

                # ad-hoc filter
                if member.instance?
                  case type_name.name
                  when :Object
                    next unless [:freeze, :block_given?, :respond_to?, :nil?, :fail, :kind_of?, :to_s].include?(name)
                  when :Array
                    next unless [:empty?, :size].include?(name)
                  when :Numeric
                    #next if name == :class
                    #next unless [:step].include?(name)
                  when :Integer
                    #next if name == :class
                    #next unless [:+, :-, :*, :/, :<, :>, :-@, :<<, :>>, :|, :&, :to_f].include?(name)
                  when :Float
                    #next unless [:+, :-, :*, :/, :<, :>, :-@].include?(name)
                  when :Math
                    #next
                  when :TrueClass, :FalseClass
                    #next unless [:!].include?(name)
                  when :Range
                    next #unless [:each].include?(name)
                  when :Kernel
                    next unless [:rand, :loop].include?(name)
                  end
                end
                if member.singleton?
                  case type_name.name
                  when :Object, :Array, :Numeric, :Integer, :Float, :Range, :TrueClass, :FalseClass
                    next
                  when :Math
                    next unless [:sqrt, :sin, :cos].include?(name)
                  end
                end

                method_types = member.types.map do |method_type|
                  case method_type
                  when MethodType
                    method_type.map_type do |type|
                      @env.absolute_type(type, namespace: type_name.to_namespace)
                    end
                  when :super
                    raise NotImplementedError
                  end
                end

                method_def = translate_typed_method_def(method_types)
                if member.instance?
                  methods << [name, method_def]
                end
                if member.singleton?
                  singleton_methods << [name, method_def]
                end
              when AST::Members::AttrReader, AST::Members::AttrAccessor, AST::Members::AttrWriter
                raise NotImplementedError
              when AST::Members::Alias
                #raise NotImplementedError # support soon!
              when AST::Members::Include
                # ad-hoc filter
                next if member.name.name != :Kernel

                name = @env.absolute_type_name(member.name, namespace: type_name.namespace)
                mod = name.namespace.path + [name.name]
                included_modules << mod
                #raise NotImplementedError # support next!
              when AST::Members::InstanceVariable
                raise NotImplementedError
              when AST::Members::ClassVariable
                raise NotImplementedError
              end
            end
          end
        end

        [klass, superclass, included_modules, methods, singleton_methods]
      end.compact

      classes
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
          # XXX: support keywords
          ##p opt_kw_tys = type.type.optional_keywords
          #p req_kw_tys = type.type.required_keywords
          #p rest_kw_ty = type.type.rest_keywords

          ret_ty = convert_type(type.type.return_type)
          [lead_tys, opt_tys, blk, ret_ty]
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
      when Ruby::Signature::Types::ClassInstance
        [:instance, ty.name.namespace.path + [ty.name.name]]
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
  end
end

target = File.join(__dir__, "../lib/type-profiler/rbs.json")
stdlib = TypeProfiler::RubySignatureReader.new
File.write(target, JSON.generate(stdlib.dump))
