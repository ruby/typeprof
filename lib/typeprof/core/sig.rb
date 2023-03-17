require "rbs"

module TypeProf::Core
  class Signatures
    def self.build(genv)
      genv.rbs_env.declarations.each do |decl|
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
          mdecl = MethodDecl.new(cpath, member.singleton?, mid, member)
          # TODO: もしすでに MethodDef があったら、
          # この RBS を前提に再解析する
          genv.add_method_decl(mdecl)
        when RBS::AST::Members::Include
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
        [Type::Instance.new(name.namespace.path + [name.name])]
      when RBS::Types::Interface
        nil # TODO...
      when RBS::Types::Bases::Bool
        [Type::Instance.new([:TrueClass]), Type::Instance.new([:FalseClass])]
      when RBS::Types::Bases::Nil
        [Type::Instance.new([:NilClass])]
      when RBS::Types::Bases::Self
        [map[:__self]]
      when RBS::Types::Bases::Void
        [Type::Instance.new([:Object])] # TODO
      when RBS::Types::Variable
        [map[type.name] || raise]
      when RBS::Types::Optional
        self.type(genv, type.type, map) + [Type::Instance.new([:NilClass])]
      else
        raise "unknown RBS type: #{ type.class }"
      end
    end
  end
end