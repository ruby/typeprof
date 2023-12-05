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
        super(raw_decl, lenv)
        @cpath = AST.resolve_rbs_name(raw_decl.name, lenv)
        # TODO: decl.type_params
        # TODO: decl.super_class.args
        ncref = CRef.new(@cpath, true, nil, lenv.cref)
        nlenv = LocalEnv.new(@lenv.path, ncref, {})
        @members = raw_decl.members.map do |member|
          AST.create_rbs_member(member, nlenv)
        end.compact
        # TODO?: param.variance, param.unchecked, param.upper_bound
        @params = raw_decl.type_params.map {|param| param.name }
      end

      attr_reader :cpath, :members, :params

      def subnodes = { members: }
      def attrs = { cpath:, params: }

      def define0(genv)
        @members.each do |member|
          member.define(genv)
        end
        mod = genv.resolve_cpath(@cpath)
        [mod.add_module_decl(genv, self)]
      end

      def undefine0(genv)
        mod = genv.resolve_cpath(@cpath)
        mod.remove_module_decl(genv, self)
        @members.each do |member|
          member.undefine(genv)
        end
      end

      def install0(genv)
        @mod_val = Source.new(Type::Singleton.new(genv, genv.resolve_cpath(@cpath)))
        @mod_val.add_edge(genv, @static_ret.first.vtx)
        @members.each do |member|
          member.install(genv)
        end
        Source.new
      end

      def uninstall0(genv)
        @mod_val.remove_edge(genv, @static_ret.first.vtx)
        super(genv)
      end
    end

    class SIG_MODULE < SigModuleNode
    end

    class SIG_CLASS < SigModuleNode
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        superclass = raw_decl.super_class
        if superclass
          name = superclass.name
          @superclass_cpath = name.namespace.path + [name.name]
          @superclass_toplevel = name.namespace.absolute?
          @superclass_args = superclass.args.map {|arg| AST.create_rbs_type(arg, lenv) }
        else
          @superclass_cpath = nil
          @superclass_toplevel = nil
          @superclass_args = nil
        end
      end

      attr_reader :superclass_cpath, :superclass_toplevel, :superclass_args

      def subnodes
        super.merge!({ superclass_args: })
      end
      def attrs
        super.merge!({ superclass_cpath:, superclass_toplevel: })
      end

      def define0(genv)
        const_reads = super(genv)
        if @superclass_cpath
          @superclass_args.each {|arg| arg.define(genv) }
          const_read = BaseConstRead.new(genv, @superclass_cpath.first, @superclass_toplevel ? CRef::Toplevel : @lenv.cref)
          const_reads << const_read
          @superclass_cpath[1..].each do |cname|
            const_read = ScopedConstRead.new(cname, const_read)
            const_reads << const_read
          end
          mod = genv.resolve_cpath(@cpath)
          const_read.followers << mod
        end
        const_reads
      end

      def undefine0(genv)
        super(genv)
        if @static_ret
          @static_ret[1..].each do |const_read|
            const_read.destroy(genv)
          end
        end
        if @superclass_args
          @superclass_args.each {|arg| arg.undefine(genv) }
        end
      end
    end

    class SIG_DEF < Node
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @mid = raw_decl.name
        @singleton = raw_decl.singleton?
        @instance = raw_decl.instance?
        @method_types = raw_decl.overloads.map do |overload|
          method_type = overload.method_type
          AST.create_rbs_func_type(method_type, method_type.type_params, method_type.block, lenv)
        end
        @overloading = raw_decl.overloading
      end

      attr_reader :mid, :singleton, :instance, :method_types, :overloading

      def subnodes = { method_types: }
      def attrs = { mid:, singleton:, instance:, overloading: }

      def install0(genv)
        [[@singleton, true], [@instance, false]].each do |enabled, singleton|
          next unless enabled
          mdecl = MethodDeclSite.new(self, genv, @lenv.cref.cpath, singleton, @mid, @method_types, @overloading)
          add_site(:mdecl, mdecl)
        end
        Source.new
      end
    end

    class SIG_INCLUDE < Node
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        name = raw_decl.name
        @cpath = name.namespace.path + [name.name]
        @toplevel = name.namespace.absolute?
        @args = raw_decl.args.map {|arg| AST.create_rbs_type(arg, lenv) }
      end

      attr_reader :cpath, :toplevel, :args
      def subnodes = { args: }
      def attrs = { cpath:, toplevel: }

      def define0(genv)
        @args.each {|arg| arg.define(genv) }
        const_reads = []
        const_read = BaseConstRead.new(genv, @cpath.first, @toplevel ? CRef::Toplevel : @lenv.cref)
        const_reads << const_read
        @cpath[1..].each do |cname|
          const_read = ScopedConstRead.new(cname, const_read)
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
        @args.each {|arg| arg.undefine(genv) }
      end

      def install0(genv)
        Source.new
      end
    end

    class SIG_ALIAS < Node
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
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
        super(raw_decl, lenv)
        @cpath = AST.resolve_rbs_name(raw_decl.name, lenv)
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :cpath, :type
      def subnodes = { type: }
      def attrs = { cpath: }

      def define0(genv)
        @type.define(genv)
        mod = genv.resolve_const(@cpath)
        mod.add_decl(self)
        mod
      end

      def undefine0(genv)
        genv.resolve_const(@cpath).remove_decl(self)
        @type.undefine(genv)
      end

      def install0(genv)
        site = TypeReadSite.new(self, genv, @type)
        add_site(:main, site)
        site.ret.add_edge(genv, @static_ret.vtx)
        site.ret
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super(genv)
      end
    end

    class SIG_TYPE_ALIAS < Node
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @cpath = AST.resolve_rbs_name(raw_decl.name, lenv)
        @name = @cpath.pop
        @type = AST.create_rbs_type(raw_decl.type, lenv)
        @params = raw_decl.type_params.map {|param| param.name }
      end

      attr_reader :cpath, :name, :type, :params

      def define0(genv)
        @type.define(genv)
        tae = genv.resolve_type_alias(@cpath, @name)
        tae.add_decl(self)
        tae
      end

      def undefine0(genv)
        tae = genv.resolve_type_alias(@cpath, @name)
        tae.remove_decl(self)
        @type.undefine(genv)
      end

      def install0(genv)
        Source.new
      end
    end

    class SIG_GVAR < Node
      def initialize(raw_decl, lenv)
        super(raw_decl, lenv)
        @var = raw_decl.name
        @type = AST.create_rbs_type(raw_decl.type, lenv)
      end

      attr_reader :cpath, :type
      def subnodes = { type: }
      def attrs = { cpath: }

      def define0(genv)
        @type.define(genv)
        mod = genv.resolve_gvar(@var)
        mod.add_decl(self)
        mod
      end

      def undefine0(genv)
        genv.resolve_gvar(@var).remove_decl(self)
        @type.undefine(genv)
      end

      def install0(genv)
        site = TypeReadSite.new(self, genv, @type)
        add_site(:main, site)
        site.ret.add_edge(genv, @static_ret.vtx)
        site.ret
      end

      def uninstall0(genv)
        @ret.remove_edge(genv, @static_ret.vtx)
        super(genv)
      end
    end
  end
end