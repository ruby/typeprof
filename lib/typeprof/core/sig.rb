require "rbs"

module TypeProf::Core
  class Sig
  end

  class Signatures
    def self.type_to_vtx(genv, node, type, param_map, cref)
      vtx = Vertex.new("type_to_vtx", node)
      type_to_vtx0(genv, node, type, vtx, param_map, cref)
      vtx
    end

    def self.type_to_vtx0(genv, node, type, vtx, param_map, cref)
      case type
      when RBS::Types::Alias
        cref0 = cref
        while cref0
          tae = genv.resolve_type_alias(cref0.cpath, type.name.name)
          break if tae.exist?
          cref0 = cref0.outer
        end
        if tae.exist?
          type_to_vtx0(genv, node, tae.decls.to_a.first.rbs_type, vtx, param_map, cref)
        else
          p "???"
          pp type.name
          Source.new # ???
        end
      when RBS::Types::Union
        type.types.each do |ty|
          type_to_vtx0(genv, node, ty, vtx, param_map, cref)
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
          elem_vtx = type_to_vtx(genv, node, elem, param_map, cref)
          Source.new(Type::Array.new(nil, elem_vtx, genv.ary_type)).add_edge(genv, vtx)
        when [:Set]
          elem = type.args.first
          elem_vtx = type_to_vtx(genv, node, elem, param_map, cref)
          Source.new(Type::Array.new(nil, elem_vtx, genv.set_type)).add_edge(genv, vtx)
        when [:Hash]
          raise if type.args.size != 2
          key_vtx = type_to_vtx(genv, node, type.args[0], param_map, cref)
          val_vtx = type_to_vtx(genv, node, type.args[1], param_map, cref)
          Source.new(Type::Hash.new({}, key_vtx, val_vtx, genv.hash_type)).add_edge(genv, vtx)
        else
          mod = genv.resolve_cpath(cpath)
          Source.new(Type::Instance.new(mod)).add_edge(genv, vtx)
        end
      when RBS::Types::Tuple
        unified_elem = Vertex.new("ary-unified", node)
        elems = type.types.map do |type|
          nvtx = type_to_vtx(genv, node, type, param_map, cref)
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
        type_to_vtx0(genv, node, type.type, vtx, param_map, cref)
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