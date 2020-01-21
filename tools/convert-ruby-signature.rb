require "ruby/signature"

class TypeProfiler
  class RubySignaturePorter
    def initialize
      loader = EnvironmentLoader.new(stdlib_root: Pathname("sigs/stdlib/"))
      @env = Environment.new()
      loader.load(env: @env)
      @builder = DefinitionBuilder.new(env: @env)

      @dump = import_ruby_signatures
    end

    attr_reader :dump

    include Ruby::Signature

    def import_ruby_signatures
      class2super = {}
      @env.each_decl do |name, decl|
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
            instance = @builder.build_instance(name)
            instance.ancestors.each do |parent|
              if @env.find_class(parent.name).is_a?(AST::Declarations::Class)
                queue << [:visit, parent.name]
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
            superclass = [:Object]
          end
          classes << [name, klass, superclass]
        end
      end

      classes = classes.map do |type_name, klass, superclass|
        methods = []
        singleton_methods = []

        if [:Object, :Array, :Numeric, :Integer, :Float, :Math].include?(type_name.name)
          methods = @builder.build_instance(type_name).methods.map do |name, rs_method|
            # XXX
            case type_name.name
            when :Object
              next unless [:rand, :freeze, :block_given?, :respond_to?, :nil?, :fail, :loop].include?(name)
            when :Array
              next unless [:empty?, :size].include?(name)
            when :Numeric
              next unless [:step].include?(name)
            when :Integer
              next unless [:+, :-, :*, :/, :<, :>, :-@, :<<, :>>, :|, :&, :to_f].include?(name)
            when :Float
              next unless [:+, :-, :*, :/, :<, :>, :-@].include?(name)
            when :Math
              next
            end

            [name, translate_typed_method_def(rs_method)]
          end.compact

          singleton_methods = @builder.build_singleton(type_name).methods.map do |name, rs_method|
            case type_name.name
            when :Object, :Array, :Numeric, :Integer, :Float
              next
            when :Math
              next unless [:sqrt, :sin, :cos].include?(name)
            end

            [name, translate_typed_method_def(rs_method)]
          end.compact
        end

        [klass, superclass, methods, singleton_methods]
      end.compact

      classes
    end

    def translate_typed_method_def(rs_method)
      rs_method.method_types.map do |type|
        unless type.type.optional_keywords.empty?
          puts "optional_keywords is not supported yet"
          next
        end
        raise NotImplementedError unless type.type.required_keywords.empty?
        raise NotImplementedError if type.type.rest_keywords

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
      when Ruby::Signature::Types::Bases::Bottom
        [:union, []]
      when Ruby::Signature::Types::Alias
        convert_type(@builder.expand_alias(ty.name))
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

target = File.join(__dir__, "../lib/type-profiler/stdlib-sigs.rb")
stdlib = TypeProfiler::RubySignaturePorter.new
File.write(target, "STDLIB_SIGS = " + stdlib.dump.pretty_inspect)
