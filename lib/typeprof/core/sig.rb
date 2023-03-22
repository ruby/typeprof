require "rbs"

module TypeProf::Core
  class Signatures
    def self.build(genv)
      genv.rbs_builder.env.declarations.each do |decl|
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
        when RBS::AST::Members::Public
        when RBS::AST::Members::Private
        when RBS::AST::Members::Alias
        when RBS::AST::Declarations::TypeAlias
        when RBS::AST::Declarations::Constant
        when RBS::AST::Declarations::Class
        when RBS::AST::Declarations::Module
        when RBS::AST::Declarations::Interface
        else
          raise "unsupported: #{ member.class }"
        end
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
          map[elem.name].map do |vtx|
            Source.new(Type::Array.new(nil, vtx))
          end
        else
          [Source.new(Type::Instance.new(cpath))]
        end
      when RBS::Types::Interface
        nil # TODO...
      when RBS::Types::Bases::Bool
        [
          Source.new(Type::Instance.new([:TrueClass])),
          Source.new(Type::Instance.new([:FalseClass])),
        ]
      when RBS::Types::Bases::Nil
        [Source.new(Type::Instance.new([:NilClass]))]
      when RBS::Types::Bases::Self
        map[:__self]
      when RBS::Types::Bases::Void
        [Source.new(Type::Instance.new([:Object]))] # TODO
      when RBS::Types::Variable
        map[type.name] || raise
      when RBS::Types::Optional
        self.type(genv, type.type, map) + [Source.new(Type::Instance.new([:NilClass]))]
      when RBS::Types::Literal
        case type.literal
        when ::Symbol
          [Source.new(Type::Symbol.new(type.literal))]
        when ::Integer
          [Source.new(Type::Instance.new([:Integer]))]
        else
          raise "unknown RBS literal: #{ type.literal.inspect }"
        end
      else
        raise "unknown RBS type: #{ type.class }"
      end
    end
  end
end