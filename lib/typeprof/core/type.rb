module TypeProf::Core
  class Type
    def base_types(_)
      [self]
    end

    def self.strip_parens(s)
      #s =~ /\A\((.*)\)\z/ ? $1 : s
      s.start_with?("(") && s.end_with?(")") ? s[1..-2] : s
    end

    class Module < Type
      include StructuralEquality

      def initialize(mod, args)
        raise unless mod.is_a?(ModuleEntity)
        # TODO: type_param
        @mod = mod
        @args = args
      end

      attr_reader :mod, :args

      def show
        "singleton(#{ @mod.show_cpath }#{ @args.empty? ? "" : "[#{ @args.map {|arg| arg.show }.join(", ") }]" })"
      end

      def match?(genv, other)
        return true if self == other

        # TODO: implement!
        return false
      end

      def get_instance_type
        Instance.new(@mod, @args)
      end
    end

    class Instance < Type
      include StructuralEquality

      def initialize(mod, args)
        raise unless mod.is_a?(ModuleEntity)
        @mod = mod
        @args = args
      end

      attr_reader :mod, :args

      def show
        case @mod.cpath
        when [:NilClass] then "nil"
        when [:TrueClass] then "true"
        when [:FalseClass] then "false"
        else
          "#{ @mod.show_cpath }#{ @args.empty? ? "" : "[#{ @args.map {|arg| arg.show }.join(", ") }]" }"
        end
      end

      def match?(genv, other)
        return true if self == other

        # TODO: base_type?
        return Instance === other && genv.subclass?(@mod.cpath, other.mod.cpath)
      end
    end

    class Array < Type
      include StructuralEquality

      def initialize(elems, unified_elem, base_type)
        @elems = elems
        raise unless unified_elem
        @unified_elem = unified_elem
        @base_type = base_type
      end

      def get_elem(genv, idx = nil)
        if idx && @elems
          @elems[idx] || Source.new(genv.nil_type)
        else
          @unified_elem
        end
      end

      def base_types(genv)
        [@base_type]
      end

      def show
        if @elems
          "[#{ @elems.map {|e| Type.strip_parens(e.show) }.join(", ") }]"
        else
          "#{ @base_type.mod.show_cpath }[#{ Type.strip_parens(@unified_elem.show) }]"
        end
      end
    end

    class Hash < Type
      include StructuralEquality

      def initialize(literal_pairs, unified_key, unified_val, base_type)
        @literal_pairs = literal_pairs
        @unified_key = unified_key
        @unified_val = unified_val
        @base_type = base_type
      end

      def get_key
        @unified_key
      end

      def get_value(key = nil)
        @literal_pairs[key] || @unified_val
      end

      def base_types(genv)
        [@base_type]
      end

      def show
        "Hash[#{ Type.strip_parens(@unified_key.show) }, #{ Type.strip_parens(@unified_val.show) }]"
      end
    end

    class Proc < Type
      def initialize(block)
        @block = block
      end

      attr_reader :block

      def base_types(genv)
        [genv.proc_type]
      end

      def show
        "<Proc>"
      end
    end

    class Symbol < Type
      include StructuralEquality

      def initialize(sym)
        @sym = sym
      end

      attr_reader :sym

      def base_types(genv)
        [genv.symbol_type]
      end

      def show
        @sym.inspect
      end
    end

    class Bot < Type
      include StructuralEquality

      def base_types(genv)
        [genv.obj_type]
      end

      def show
        "bot"
      end
    end

    def self.rbs_type_to_vtx(genv, node, type, param_map, cref)
      vtx = Vertex.new("rbs_type", node)
      rbs_type_to_vtx0(genv, node, type, vtx, param_map, cref)
      vtx
    end

    def self.rbs_type_to_vtx0(genv, node, type, vtx, param_map, cref)
      case type
      when RBS::Types::Alias
        cref0 = cref
        while cref0
          tae = genv.resolve_type_alias(cref0.cpath + type.name.namespace.path, type.name.name)
          break if tae.exist?
          cref0 = cref0.outer
        end
        if tae.exist?
          rbs_type_to_vtx0(genv, node, tae.decls.to_a.first.rbs_type, vtx, param_map, cref)
        else
          p "???"
          pp type.name
          Source.new # ???
        end
      when RBS::Types::Union
        type.types.each do |ty|
          rbs_type_to_vtx0(genv, node, ty, vtx, param_map, cref)
        end
      when RBS::Types::Intersection
        Source.new # TODO
      when RBS::Types::ClassSingleton
        Source.new # TODO
      when RBS::Types::ClassInstance
        name = type.name
        cpath = name.namespace.path + [name.name]
        case cpath
        when [:Array]
          raise if type.args.size != 1
          elem = type.args.first
          elem_vtx = rbs_type_to_vtx(genv, node, elem, param_map, cref)
          Source.new(Type::Array.new(nil, elem_vtx, genv.ary_type)).add_edge(genv, vtx)
        when [:Set]
          elem = type.args.first
          elem_vtx = rbs_type_to_vtx(genv, node, elem, param_map, cref)
          Source.new(Type::Array.new(nil, elem_vtx, genv.set_type)).add_edge(genv, vtx)
        when [:Hash]
          raise if type.args.size != 2
          key_vtx = rbs_type_to_vtx(genv, node, type.args[0], param_map, cref)
          val_vtx = rbs_type_to_vtx(genv, node, type.args[1], param_map, cref)
          Source.new(Type::Hash.new({}, key_vtx, val_vtx, genv.hash_type)).add_edge(genv, vtx)
        else
          # TODO: resolve with cref
          # TODO: type.args
          mod = genv.resolve_cpath(cpath)
          Source.new(Type::Instance.new(mod, [])).add_edge(genv, vtx)
        end
      when RBS::Types::Tuple
        unified_elem = Vertex.new("ary-unified", node)
        elems = type.types.map do |type|
          nvtx = rbs_type_to_vtx(genv, node, type, param_map, cref)
          nvtx.add_edge(genv, unified_elem)
          nvtx
        end
        Source.new(Type::Array.new(elems, unified_elem, genv.ary_type)).add_edge(genv, vtx)
      when RBS::Types::Interface
        # TODO...
      when RBS::Types::Bases::Bool
        Source.new(genv.true_type, genv.false_type).add_edge(genv, vtx)
      when RBS::Types::Bases::Nil
        Source.new(genv.nil_type).add_edge(genv, vtx)
      when RBS::Types::Bases::Self
        param_map[:__self].add_edge(genv, vtx)
      when RBS::Types::Bases::Void
        Source.new(genv.obj_type).add_edge(genv, vtx) # TODO
      when RBS::Types::Bases::Any
        Source.new().add_edge(genv, vtx) # TODO
      when RBS::Types::Bases::Top
        Source.new().add_edge(genv, vtx)
      when RBS::Types::Bases::Bottom
        Source.new(Type::Bot.new).add_edge(genv, vtx)
      when RBS::Types::Variable
        if param_map[type.name]
          param_map[type.name].add_edge(genv, vtx)
        else
          #puts "unknown type param: #{ type.name }"
        end
      when RBS::Types::Optional
        rbs_type_to_vtx0(genv, node, type.type, vtx, param_map, cref)
        Source.new(genv.nil_type).add_edge(genv, vtx)
      when RBS::Types::Literal
        ty = case type.literal
        when ::Symbol
          Type::Symbol.new(type.literal)
        when ::Integer then genv.int_type
        when ::String then genv.str_type
        when ::TrueClass then genv.true_type
        when ::FalseClass then genv.false_type
        else
          raise "unknown RBS literal: #{ type.literal.inspect }"
        end
        Source.new(ty).add_edge(genv, vtx)
      else
        raise "unknown RBS type: #{ type.class }"
      end
    end
  end
end