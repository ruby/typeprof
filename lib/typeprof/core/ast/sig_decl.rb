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
      def initialize(raw_decl, lenv)
        super
        @mid = raw_decl.name
        @singleton = raw_decl.singleton?
        @instance = raw_decl.instance?
        @method_types = raw_decl.overloads.map do |overload|
          AST.create_rbs_func_type(overload.method_type.type, overload.method_type.block, lenv)
        end
      end

      attr_reader :mid, :singleton, :instance, :method_types

      def subnodes = { method_types: }
      def attrs = { mid:, singleton:, instance: }

      def install0(genv)
        [[@singleton, true], [@instance, false]].each do |enabled, singleton|
          next unless enabled
          mdecl = MethodDeclSite.new(self, genv, @lenv.cref.cpath, singleton, @mid, @method_types)
          add_site(:mdecl, mdecl)
        end
        Source.new
      end
    end

    class SIG_INCLUDE < Node
      def initialize(raw_decl, lenv)
        super
        name = raw_decl.name
        @cpath = name.namespace.path + [name.name]
        @toplevel = name.namespace.absolute?
        @args = raw_decl.args
      end

      attr_reader :cpath, :toplevel, :args
      def attrs = { cpath:, toplevel:, args: }

      def define0(genv)
        const_reads = []
        const_read = BaseConstRead.new(genv, @cpath.first, @toplevel ? CRef::Toplevel : @lenv.cref)
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
      def initialize(raw_decl, lenv)
        super
        @new_mid = raw_decl.new_name
        @old_mid = raw_decl.old_name
        @singleton = raw_decl.singleton?
        @instance = raw_decl.instance?
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
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :cpath, :type
      def subnodes = { type: }
      def attrs = { cpath: }

      def define0(genv)
        @type.define(genv)
        mod = genv.resolve_const(@cpath)
        mod.decls << self
        mod
      end

      def undefine0(genv)
        genv.resolve_const(@cpath).decls.delete(self)
        @type.undefine(genv)
      end

      def install0(genv)
        val = @type.get_vertex(genv, {})
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
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :cpath, :name, :rbs_type

      def define0(genv)
        @type.define(genv)
        tae = genv.resolve_type_alias(@cpath, @name)
        tae.decls << self
        tae
      end

      def undefine0(genv)
        genv.resolve_type_alias(@cpath, @name).decls.delete(self)
        @type.undefine(genv)
      end

      def install0(genv)
        Source.new
      end
    end

    class SIG_GVAR < Node
      def initialize(raw_decl, lenv)
        super
        @var = raw_decl.name
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :cpath, :type
      def subnodes = { type: }
      def attrs = { cpath: }

      def define0(genv)
        @type.define(genv)
        mod = genv.resolve_gvar(@var)
        mod.decls << self
        mod
      end

      def undefine0(genv)
        genv.resolve_gvar(@var).decls.delete(self)
        @type.undefine(genv)
      end

      def install0(genv)
        val = @type.get_vertex(genv, {})
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