module TypeProf::Core
  class Sig::AST
    def self.parse(path, src)
      _buffer, _directives, raw_decls = RBS::Parser.parse_signature(src)

      raw_decls.map do |raw_decl|
        Sig::AST.create_decl(raw_decl, [])
      end
    end

    def self.create_decl(raw_decl, base_cpath)
      case raw_decl
      when RBS::AST::Declarations::Class
        CLASS.new(raw_decl, base_cpath)
      when RBS::AST::Declarations::Module
        MODULE.new(raw_decl, base_cpath)
      when RBS::AST::Declarations::Constant
      when RBS::AST::Declarations::AliasDecl
      when RBS::AST::Declarations::TypeAlias
        # TODO: check
      when RBS::AST::Declarations::Interface
      when RBS::AST::Declarations::Global
      else
        raise "unsupported: #{ raw_decl.class }"
      end
    end

    def self.create_member(raw_member, base_cpath)
      case raw_member
      when RBS::AST::Members::MethodDefinition
        DEF.new(raw_member, base_cpath)
      end
    end

    class Node
      def initialize(raw_rbs, base_cpath)
        @raw_rbs = raw_rbs
        @base_cpath = base_cpath
        @static_ret = nil
        @ret = nil
        @sites = {}
      end

      attr_reader :raw_rbs

      def subnodes = {}
      def attrs = {}

      def each_subnode(&blk)
        subnodes.each_value do |subnode|
          next unless subnode
          case subnode
          when Sig::AST::Node
            yield subnode
          when Array
            subnode.each {|n| yield n }
          else
            raise subnode.class.to_s
          end
        end
      end

      def add_site(key, site)
        (@sites[key] ||= Set[]) << site
      end

      def remove_site(key, site)
        @sites[key].delete(site)
      end

      def define(genv)
        @static_ret = define0(genv)
      end

      def define0(genv)
        each_subnode do |subnode|
          subnode.define(genv)
        end
      end

      def undefine(genv)
        undefine0(genv)
      end

      def undefine0(genv)
        each_subnode do |subnode|
          subnode.undefine(genv)
        end
      end

      def install(genv)
        @ret = install0(genv)
      end

      def install0(_)
        raise "should override???"
      end

      def uninstall(genv)
        @sites.each_value do |sites|
          sites.each do |site|
            site.destroy(genv)
          end
        end
        uninstall0(genv)
      end

      def uninstall0(genv)
        each_subnode do |subnode|
          subnode.uninstall(genv)
        end
      end
    end

    class ModuleNode < Node
      def initialize(raw_decl, base_cpath)
        super
        name = raw_decl.name
        if name.namespace.absolute?
          @cpath = name.namespace.path + [name.name]
        else
          @cpath = base_cpath + name.namespace.path + [name.name]
        end
        # TODO: decl.type_params
        # TODO: decl.super_class.args
        @members = raw_decl.members.map do |member|
          Sig::AST.create_member(member, @cpath)
        end
      end

      attr_reader :cpath, :members

      def subnodes = { members: }
      def attrs = { cpath: }

      def define0(genv)
        @members.each do |member|
          member.define(genv)
        end
        mod = genv.resolve_cpath(@cpath)
        mod.add_module_decl(genv, self)
      end

      def undefine0(genv)
        mod = genv.resolve_cpath(@cpath)
        mod.remove_module_def(genv, self)
        @members.each do |member|
          member.undefine(genv)
        end
      end

      def install0(genv)
        val = Source.new(Type::Module.new(genv.resolve_cpath(@cpath)))
        val.add_edge(genv, @static_ret.vtx)
        @members.each do |member|
          member.install(genv)
        end
        nil
      end
    end

    class MODULE < ModuleNode
    end

    class CLASS < ModuleNode
      def initialize(raw_decl, base_cpath)
        super
        superclass = raw_decl.super_class
        if superclass
          @superclass_cpath = superclass.name.name.path + [superclass.name.name]
        else
          @superclass_cpath = nil
        end
      end

      attr_reader :superclass_cpath

      def attrs
        super.merge!({ superclass_cpath: })
      end
    end

    class DEF < Node
      def initialize(raw_member, base_cpath)
        super
        @mid = raw_member.name
        @singleton = raw_member.singleton?
        @instance = raw_member.instance?
      end

      def install0(genv)
        rbs_method_types = @raw_rbs.overloads.map {|overload| overload.method_type }
        if @singleton
          mdecl = MethodDeclSite.new(self, genv, @base_cpath, true, @mid, rbs_method_types)
          add_site(:mdecl, mdecl)
        end
        if @instance
          mdecl = MethodDeclSite.new(self, genv, @base_cpath, false, @mid, rbs_method_types)
          add_site(:mdecl, mdecl)
        end
      end
    end
  end
end