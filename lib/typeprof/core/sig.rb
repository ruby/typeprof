require "rbs"

module TypeProf::Core
  class Signatures
    def self.build(genv)
      genv.rbs_builder.env.declarations.each do |decl|
        declaration(genv, decl)
      end
    end

    def self.declaration(genv, decl)
      case decl
      when RBS::AST::Declarations::Class
        name = decl.name
        cpath = name.namespace.path + [name.name]
        # TODO: decl.type_params
        # TODO: decl.super_class.args
        superclass = decl.super_class&.name
        if superclass
          superclass_cpath = superclass.namespace.path + [superclass.name]
        else
          superclass_cpath = [:Object]
        end
        genv.add_module(cpath, decl, superclass_cpath)
        ty = Type::Module.new(cpath)
        cdecl = ConstDecl.new(cpath[0..-2], cpath[-1], ty)
        genv.add_const_decl(cdecl)
        members(genv, cpath, decl.members)
      when RBS::AST::Declarations::Module
        name = decl.name
        cpath = name.namespace.path + [name.name]
        genv.add_module(cpath, decl)
        ty = Type::Module.new(cpath)
        cdecl = ConstDecl.new(cpath[0..-2], cpath[-1], ty)
        genv.add_const_decl(cdecl)
        members(genv, cpath, decl.members)
      when RBS::AST::Declarations::Constant
        name = decl.name
        cpath = name.namespace.path + [name.name]
        ty = Type::RBS.new(decl.type)
        cdecl = ConstDecl.new(cpath[0..-2], cpath[-1], ty)
        genv.add_const_decl(cdecl)
      when RBS::AST::Declarations::AliasDecl
      when RBS::AST::Declarations::TypeAlias
        # TODO: check
      when RBS::AST::Declarations::Interface
      when RBS::AST::Declarations::Global
        ty = Type::RBS.new(decl.type)
        gvdecl = GVarDecl.new(decl.name, ty)
        genv.add_gvar_decl(gvdecl)
      else
        raise "unsupported: #{ decl.class }"
      end
    end

    def self.members(genv, cpath, members)
      members.each do |member|
        case member
        when RBS::AST::Members::MethodDefinition
          mid = member.name
          # TODO: もしすでに MethodDef があったら、
          # この RBS を前提に再解析する
          if member.singleton?
            mdecl = MethodDecl.new(cpath, true, mid, member)
            genv.add_method_decl(mdecl)
          end
          if member.instance?
            mdecl = MethodDecl.new(cpath, false, mid, member)
            genv.add_method_decl(mdecl)
          end
        when RBS::AST::Members::Include
          name = member.name
          mod_cpath = name.namespace.path + [name.name]
          genv.add_module_include(cpath, mod_cpath)
        when RBS::AST::Members::Extend
        when RBS::AST::Members::Public
        when RBS::AST::Members::Private
        when RBS::AST::Members::Alias
          if member.singleton?
            mdecl_new = MethodDecl.new(cpath, true, member.new_name, member)
            mdecl_old = MethodDecl.new(cpath, true, member.old_name, nil)
            genv.add_method_alias(mdecl_new, mdecl_old)
          end
          if member.instance?
            mdecl_new = MethodDecl.new(cpath, false, member.new_name, member)
            mdecl_old = MethodDecl.new(cpath, false, member.old_name, nil)
            genv.add_method_alias(mdecl_new, mdecl_old)
          end
        when
          RBS::AST::Declarations::TypeAlias,
          RBS::AST::Declarations::Constant,
          RBS::AST::Declarations::Class,
          RBS::AST::Declarations::Module,
          RBS::AST::Declarations::Interface

          declaration(genv, member)
        else
          raise "unsupported: #{ member.class }"
        end
      end
    end

    def self.type_to_vtx(genv, node, type, param_map)
      vtx = Vertex.new("type_to_vtx", node)
      type_to_vtx0(genv, node, type, vtx, param_map)
      vtx
    end

    def self.type_to_vtx0(genv, node, type, vtx, param_map)
      case type
      when RBS::Types::Alias
        type_to_vtx0(genv, node, genv.rbs_builder.expand_alias(type.name), vtx, param_map)
      when RBS::Types::Union
        type.types.each do |ty|
          type_to_vtx0(genv, node, ty, vtx, param_map)
        end
      when RBS::Types::ClassInstance
        name = type.name
        cpath = name.namespace.path + [name.name]
        if cpath == [:Array]
          raise if type.args.size != 1
          elem = type.args.first
          elem_vtx = type_to_vtx(genv, node, elem, param_map)
          Source.new(Type::Array.new(nil, elem_vtx, Type.ary)).add_edge(genv, vtx)
        else
          Source.new(Type::Instance.new(cpath)).add_edge(genv, vtx)
        end
      when RBS::Types::Tuple
        unified_elem = Vertex.new("ary-unified", node)
        elems = type.types.map do |type|
          nvtx = type_to_vtx(genv, node, type, param_map)
          nvtx.add_edge(genv, unified_elem)
          nvtx
        end
        Source.new(Type::Array.new(elems, unified_elem, Type.ary)).add_edge(genv, vtx)
      when RBS::Types::Interface
        # TODO...
      when RBS::Types::Bases::Bool
        Source.new(Type.true, Type.false).add_edge(genv, vtx)
      when RBS::Types::Bases::Nil
        Source.new(Type.nil).add_edge(genv, vtx)
      when RBS::Types::Bases::Self
        param_map[:__self].add_edge(genv, vtx)
      when RBS::Types::Bases::Void
        Source.new(Type.obj).add_edge(genv, vtx) # TODO
      when RBS::Types::Bases::Any
        Source.new().add_edge(genv, vtx) # TODO
      when RBS::Types::Bases::Bottom
        # TODO...
      when RBS::Types::Variable
        if param_map[type.name]
          param_map[type.name].add_edge(genv, vtx)
        else
          puts "unknown type param: #{ type.name }"
        end
      when RBS::Types::Optional
        type_to_vtx0(genv, node, type.type, vtx, param_map)
        Source.new(Type.nil).add_edge(genv, vtx)
      when RBS::Types::Literal
        ty = case type.literal
        when ::Symbol
          Type::Symbol.new(type.literal)
        when ::Integer then Type.int
        when ::String then Type.str
        when ::TrueClass then Type.true
        when ::FalseClass then Type.false
        else
          raise "unknown RBS literal: #{ type.literal.inspect }"
        end
        Source.new(ty).add_edge(genv, vtx)
      else
        raise "unknown RBS type: #{ type.class }"
      end
    end

    def self.type(genv, type, map)
      case type
      when RBS::Types::Alias
        self.type(genv, genv.rbs_builder.expand_alias(type.name), map)
      when RBS::Types::Union
        type.types.flat_map do |ty|
          self.type(genv, ty, map)
        end.compact
      when RBS::Types::ClassInstance
        name = type.name
        cpath = name.namespace.path + [name.name]
        if cpath == [:Array]
          raise if type.args.size != 1
          elem = type.args.first
          if elem.is_a?(RBS::Types::Tuple)
            # TODO!!!
            raise
            [Source.new(Type.obj)] # TODO!!!
          else
            map[elem.name].map do |vtx|
              Source.new(Type::Array.new(nil, vtx, Type.ary))
            end
          end
        else
          [Source.new(Type::Instance.new(cpath))]
        end
      when RBS::Types::Tuple
        raise
        [Source.new(Type.obj)] # TODO!!!
      when RBS::Types::Interface
        nil # TODO...
      when RBS::Types::Bases::Bool
        [
          Source.new(Type.true),
          Source.new(Type.false),
        ]
      when RBS::Types::Bases::Nil
        [Source.new(Type.nil)]
      when RBS::Types::Bases::Self
        map[:__self]
      when RBS::Types::Bases::Void
        [Source.new(Type.obj)] # TODO
      when RBS::Types::Bases::Any
        [Source.new(Type.obj)] # TODO
      when RBS::Types::Bases::Bottom
        [Source.new()] # TODO
      when RBS::Types::Variable
        map[type.name] || [Source.new()] # TODO
      when RBS::Types::Optional
        self.type(genv, type.type, map) + [Source.new(Type.nil)]
      when RBS::Types::Literal
        case type.literal
        when ::Symbol
          [Source.new(Type::Symbol.new(type.literal))]
        when ::Integer
          [Source.new(Type.int)]
        when ::String
          [Source.new(Type.str)]
        when ::TrueClass
          [Source.new(Type.true)]
        when ::FalseClass
          [Source.new(Type.false)]
        else
          raise "unknown RBS literal: #{ type.literal.inspect }"
        end
      else
        raise "unknown RBS type: #{ type.class }"
      end
    end
  end
end