module TypeProf::Core
  class AST
    class SigModuleNode < Node
      def initialize(raw_decl, lenv)
        super
        name = raw_decl.name
        if name.namespace.absolute?
          @cpath = name.namespace.path + [name.name]
        else
          @cpath = @lenv.cref.cpath + name.namespace.path + [name.name]
        end
        # TODO: decl.type_params
        # TODO: decl.super_class.args
        ncref = CRef.new(@cpath, true, lenv.cref)
        nlenv = LocalEnv.new(@lenv.path, ncref, {})
        @members = raw_decl.members.map do |member|
          AST.create_rbs_member(member, nlenv)
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
        Source.new
      end
    end

    class SIG_MODULE < SigModuleNode
    end

    class SIG_CLASS < SigModuleNode
      def initialize(raw_decl, lenv)
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

    class SIG_DEF < Node
      def initialize(raw_member, lenv)
        super
        @mid = raw_member.name
        @singleton = raw_member.singleton?
        @instance = raw_member.instance?
      end

      def install0(genv)
        rbs_method_types = @raw_node.overloads.map {|overload| overload.method_type }
        if @singleton
          mdecl = MethodDeclSite.new(self, genv, @lenv.cref.cpath, true, @mid, rbs_method_types)
          add_site(:mdecl, mdecl)
        end
        if @instance
          mdecl = MethodDeclSite.new(self, genv, @lenv.cref.cpath, false, @mid, rbs_method_types)
          add_site(:mdecl, mdecl)
        end
        Source.new
      end
    end
  end
end