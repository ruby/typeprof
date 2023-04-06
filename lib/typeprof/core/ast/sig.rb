module TypeProf::Core
  class AST
    def self.resolve_rbs_name(name, lenv)
      if name.namespace.absolute?
        name.namespace.path + [name.name]
      else
        lenv.cref.cpath + name.namespace.path + [name.name]
      end
    end

    class SigModuleNode < Node
      def initialize(raw_decl, lenv)
        super
        @cpath = AST.resolve_rbs_name(raw_decl.name, lenv)
        # TODO: decl.type_params
        # TODO: decl.super_class.args
        ncref = CRef.new(@cpath, true, lenv.cref)
        nlenv = LocalEnv.new(@lenv.path, ncref, {})
        @members = raw_decl.members.map do |member|
          AST.create_rbs_member(member, nlenv)
        end.compact
        #@params = raw_decl.type_params
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
        val = Source.new(Type::Module.new(genv.resolve_cpath(@cpath), []))
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
          @superclass_cpath = AST.resolve_rbs_name(superclass.name, lenv)
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
        [[@singleton, true], [@instance, false]].each do |enabled, singleton|
          next unless enabled
          mdecl = MethodDeclSite.new(self, genv, @lenv.cref.cpath, singleton, @mid, rbs_method_types)
          add_site(:mdecl, mdecl)
        end
        Source.new
      end
    end

    class SIG_INCLUDE < Node
      def initialize(raw_member, lenv)
        super
        name = raw_member.name
        @cpath = name.namespace.path + [name.name]
        @toplevel = name.namespace.absolute?
        @args = raw_member.args
      end

      attr_reader :cpath, :toplevel, :args
      def attrs = { cpath:, toplevel:, args: }

      def define0(genv)
        const_reads = []
        const_read = BaseConstRead.new(genv, cpath.first, @toplevel ? CRef::Toplevel : @lenv.cref)
        const_reads << const_read
        cpath[1..].each do |cname|
          const_read = ScopedConstRead.new(genv, cname, const_read)
          const_reads << const_read
        end
        mod = genv.resolve_cpath(@lenv.cref.cpath)
        const_read.followers << mod
        mod.add_include_decl(genv, self)
        const_reads
      end

      def undefine0(genv)
        mod = genv.resolve_cpath(@lenv.cref.cpath)
        mod.remove_include_decl(genv, self)
        @static_ret.each do |const_read|
          const_read.destroy(genv)
        end
      end

      def install0(genv)
        Source.new
      end
    end

    class SIG_ALIAS < Node
      def initialize(raw_member, lenv)
        super
        @new_mid = raw_member.new_name
        @old_mid = raw_member.old_name
        @singleton = raw_member.singleton?
        @instance = raw_member.instance?
      end

      attr_reader :new_mid, :old_mid, :singleton, :instance
      def attrs = { new_mid:, old_mid:, singleton:, instance: }

      def install0(genv)
        [[@singleton, true], [@instance, false]].each do |enabled, singleton|
          next unless enabled
          me = genv.resolve_method(@lenv.cref.cpath, singleton, @new_mid)
          me.add_alias(self, @old_mid)
          me.add_run_all_callsites(genv)
        end
        Source.new
      end

      def uninstall0(genv)
        [[@singleton, true], [@instance, false]].each do |enabled, singleton|
          next unless enabled
          me = genv.resolve_method(@lenv.cref.cpath, singleton, @new_mid)
          me.remove_alias(self, @old_mid)
          me.add_run_all_callsites(genv)
        end
      end
    end

    class SIG_CONST < Node
      def initialize(raw_decl, lenv)
        super
        @cpath = AST.resolve_rbs_name(raw_decl.name, lenv)
        @raw_type = raw_decl.type
      end

      attr_reader :cpath, :raw_type
      def attrs = { cpath:, raw_type: }

      def define0(genv)
        mod = genv.resolve_const(@cpath)
        mod.decls << self
        mod
      end

      def undefine0(genv)
        genv.resolve_const(@cpath).decls.delete(self)
      end

      def install0(genv)
        val = Type.rbs_type_to_vtx(genv, self, @raw_type, {}, @lenv.cref)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super
      end
    end

    class SIG_TYPE_ALIAS < Node
      def initialize(raw_decl, lenv)
        super
        @cpath = AST.resolve_rbs_name(raw_decl.name, lenv)
        @name = @cpath.pop
        @rbs_type = raw_decl.type
      end

      attr_reader :cpath, :name, :rbs_type

      def define0(genv)
        tae = genv.resolve_type_alias(@cpath, @name)
        tae.decls << self
        tae
      end

      def undefine0(genv)
        genv.resolve_type_alias(@cpath, @name).decls.delete(self)
      end

      def install0(genv)
        Source.new
      end
    end

    class SIG_GVAR < Node
      def initialize(raw_decl, lenv)
        super
        @var = raw_decl.name
        @raw_type = raw_decl.type
      end

      attr_reader :var, :raw_type
      def attrs = { var:, raw_type: }

      def define0(genv)
        mod = genv.resolve_gvar(@var)
        mod.decls << self
        mod
      end

      def undefine0(genv)
        genv.resolve_gvar(@var).decls.delete(self)
      end

      def install0(genv)
        val = Type.rbs_type_to_vtx(genv, self, @raw_type, {}, @lenv.cref)
        val.add_edge(genv, @static_ret.vtx)
        val
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super
      end
    end
  end
end