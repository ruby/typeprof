module TypeProf
  class ModuleNode
    def initialize
      @module_defs = Set.new
      @child_modules = {}
      @superclass_cpath = nil

      @consts = {}
      @singleton_methods = {}
      @instance_methods = {}
    end

    def set_superclass_path(cpath)
      @superclass_path = cpath
    end

    attr_reader :module_defs, :child_modules
    attr_accessor :superclass_cpath
    attr_reader :consts, :singleton_methods, :instance_methods
  end

  class MethodEntity
    def initialize
      @decls = Set.new
      @defs = Set.new
    end

    attr_reader :decls, :defs
  end

  class ConstEntity
    def initialize
      @decls = Set.new
      @defs = Set.new
      @tyvar = Variable.new("(const)")
    end

    attr_reader :decls, :defs, :tyvar
  end

  class GlobalEnv
    def initialize
      @run_queue = []
      @run_queue_set = Set.new

      @toplevel = ModuleNode.new

      loader = RBS::EnvironmentLoader.new
      @rbs_env = RBS::Environment.from_loader(loader).resolve_type_names
      @rbs_builder = RBS::DefinitionBuilder.new(env: rbs_env)

      @callsites_by_name = {}
      @readsites_by_name = {}
    end

    attr_reader :rbs_env, :rbs_builder

    def add_run(obj)
      unless @run_queue_set.include?(obj)
        @run_queue << obj
        @run_queue_set << obj
      end
    end

    def run_all
      until @run_queue.empty?
        obj = @run_queue.shift
        @run_queue_set.delete(obj)
        obj.run(self)
      end
    end

    def resolve_cpath(cpath)
      node = @toplevel
      cpath.each do |cname|
        node = node.child_modules[cname] ||= ModuleNode.new
      end
      node
    end

    def add_module(cpath, mod_def)
      node = resolve_cpath(cpath)
      node.module_defs << mod_def
      node
    end

    def remove_module(cpath, mod_def)
      node = resolve_cpath(cpath)
      node.module_defs.delete(mod_def)
    end

    def set_superclass(cpath, superclass_cpath)
      node = resolve_cpath(cpath)
      node.superclass_cpath = superclass_cpath
    end

    def add_const(cpath, cname, const_def)
      node = resolve_cpath(cpath)
      e = node.consts[cname] ||= ConstEntity.new
      e.defs << const_def

      readsites = @readsites_by_name[cname]
      if readsites
        readsites.each do |readsite|
          add_run(readsite)
        end
      end

      e.tyvar
    end

    def remove_const(cpath, cname, const_def)
      node = resolve_cpath(cpath)
      e = node.consts[cname]
      e.defs.delete(const_def)

      readsites = @readsites_by_name[cname]
      if readsites
        readsites.each do |readsite|
          add_run(readsite)
        end
      end
    end

    def get_const(cpath, cname)
      node = resolve_cpath(cpath)
      node.consts[cname]
    end

    def get_method_entity(cpath, singleton, mid)
      node = resolve_cpath(cpath)
      methods = singleton ? node.singleton_methods : node.instance_methods
      methods[mid] ||= MethodEntity.new
    end

    def add_method_decl(mdecl)
      e = get_method_entity(mdecl.cpath, mdecl.singleton, mdecl.mid)
      e.decls << mdecl
    end

    def add_method_def(mdef)
      e = get_method_entity(mdef.cpath, mdef.singleton, mdef.mid)
      e.defs << mdef

      # メソッドが定義されたので再解析
      # TODO: クラス階層上、再解析が必要なところだけにする
      callsites = @callsites_by_name[mdef.mid]
      if callsites
        callsites.each do |callsite|
          add_run(callsite)
        end
      end
    end

    def remove_method_def(mdef)
      node = resolve_cpath(mdef.cpath)
      methods = mdef.singleton ? node.singleton_methods : node.instance_methods
      methods[mdef.mid].defs.delete(mdef)

      callsites = @callsites_by_name[mdef.mid]
      if callsites
        callsites.each do |callsite|
          add_run(callsite)
        end
      end
    end

    def resolve_method(cpath, singleton, mid)
      while true
        node = resolve_cpath(cpath)
        methods = singleton ? node.singleton_methods : node.instance_methods
        e = methods[mid]
        if e
          return e.decls unless e.decls.empty?
          return e.defs unless e.defs.empty?
        end
        if cpath == [:BasicObject]
          if singleton
            singleton = false
            cpath = [:Class]
          else
            return nil
          end
        else
          cpath = node.superclass_cpath
        end
      end
    end

    def add_callsite(callsite)
      (@callsites_by_name[callsite.mid] ||= Set.new) << callsite
    end

    def remove_callsite(callsite)
      @callsites_by_name.delete(callsite.mid)
    end

    def add_readsite(readsite)
      (@readsites_by_name[readsite.cname] ||= Set.new) << readsite
    end

    def remove_readsite(readsite)
      @readsites_by_name.delete(readsite.cname)
    end
  end
end