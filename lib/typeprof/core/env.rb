module TypeProf::Core
  class Entity
    def initialize
      @decls = Set[]
      @defs = Set[]
      @vtx = Vertex.new("gvar", self)
    end

    attr_reader :decls, :defs, :vtx

    def add_decl(decl, vtx)
      @decls << decl
      @vtx = vtx # TODO
    end

    def remove_decl(decl)
      @decls.delete(decl)
    end

    def add_def(node)
      @defs << node
      self
    end

    def remove_def(node)
      @defs.delete(node)
    end

    def exist?
      !@decls.empty? || !@defs.empty?
    end
  end

  class OldEntity
    def initialize
      @decls = Set[]
      @defs = Set[]
      @aliases = Set[]
    end

    attr_reader :decls, :defs, :aliases
  end

  class GlobalEnv
    def initialize(rbs_builder)
      @define_queue = []

      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleDirectory.new([])
      @toplevel.child_modules[:Object] = @toplevel

      @gvars = {}

      @rbs_builder = rbs_builder

      @callsites_by_name = {}
      @ivreadsites_by_name = {}
    end

    attr_reader :rbs_builder

    def define_all
      @define_queue.uniq.each do |v|
        case v
        when Array # cpath
          resolve_cpath(v).on_child_modules_updated(self)
        when BaseConstRead
          v.on_scope_updated(self)
        else
          raise
        end
      end
      @define_queue.clear
    end

    def add_run(obj)
      unless @run_queue_set.include?(obj)
        @run_queue << obj
        @run_queue_set << obj
      end
    end

    def run_all
      until @run_queue.empty?
        obj = @run_queue.shift
        raise unless obj # annotation
        @run_queue_set.delete(obj)
        obj.run(self)
      end
    end

    # just for validation
    def get_vertexes_and_boxes(vtxs)
      @toplevel.get_vertexes_and_boxes(vtxs)
      @gvars.each_value do |gvar_entity|
        vtxs << gvar_entity.vtx
      end
    end

    # classes and modules

    def resolve_cpath(cpath)
      dir = @toplevel
      raise unless cpath # annotation
      cpath.each do |cname|
        dir = dir.child_modules[cname] ||= ModuleDirectory.new(dir.cpath + [cname])
      end
      dir
    end

    def add_define_queue(cpath)
      @define_queue << cpath
    end

    # module inclusion

    def add_module_include(cpath, mod_cpath)
      dir = resolve_cpath(cpath)
      dir.include_module_cpaths << mod_cpath
    end

    # TODO: remove_method_include

    # constants

    def resolve_const(cpath)
      dir = resolve_cpath(cpath[0..-2])
      dir.child_consts[cpath[-1]] ||= Entity.new
    end

    def add_const_read(const_read)
      cref = const_read.cref
      while cref
        resolve_cpath(cref.cpath).const_reads << const_read
        cref = cref.outer
      end
      @define_queue << const_read
    end

    def remove_const_read(const_read)
      cref = const_read.cref
      while cref
        resolve_cpath(cref.cpath).const_reads.delete(const_read)
        cref = cref.outer
      end
    end

    # methods

    def resolve_meth(cpath, singleton, mid)
      dir = resolve_cpath(cpath)
      dir.methods[singleton][mid] ||= MethodEntity.new
    end

    def get_method_entity(me)
      dir = resolve_cpath(me.cpath)
      dir.methods_old(me.singleton)[me.mid] ||= OldEntity.new
    end

    def add_method_decl(mdecl)
      e = get_method_entity(mdecl)
      e.decls << mdecl
    end

    def add_method_def(mdef)
      e = get_method_entity(mdef)
      e.defs << mdef

      run_callsite(mdef.mid)
    end

    def remove_method_def(mdef)
      e = get_method_entity(mdef)
      e.defs.delete(mdef)

      run_callsite(mdef.mid)
    end

    def add_method_alias(malias)
      e = get_method_entity(malias)
      e.aliases << malias

      run_callsite(malias.mid)
    end

    def remove_method_alias(malias)
      e = get_method_entity(malias)
      e.aliases.delete(malias)

      run_callsite(malias.mid)
    end

    def resolve_method(cpath, singleton, mid)
      enumerate_methods(cpath, singleton) do |_cpath, _singleton, methods|
        e = methods[mid]
        if e
          return e.decls unless e.decls.empty?
          return e.defs unless e.defs.empty?
          unless e.aliases.empty?
            # TODO
            mid = e.aliases.to_a.first.old_mid
            redo
          end
        end
      end
    end

    def enumerate_methods(cpath, singleton)
      while true
        dir = resolve_cpath(cpath)
        yield cpath, singleton, dir.methods_old(singleton)
        unless singleton # TODO
          dir.include_module_cpaths.each do |mod_cpath|
            mod_dir = resolve_cpath(mod_cpath)
            yield mod_cpath, false, mod_dir.methods_old(false)
          end
        end
        if cpath == [:BasicObject]
          if singleton
            singleton = false
            cpath = [:Class]
          else
            break
          end
        else
          cpath = dir.superclass_cpath
          unless cpath
            cpath = [:Module]
            singleton = false
          end
        end
      end
    end

    def add_callsite(callsite)
      (@callsites_by_name[callsite.mid] ||= Set[]) << callsite
      add_run(callsite)
    end

    def remove_callsite(callsite)
      @callsites_by_name[callsite.mid].delete(callsite)
    end

    def run_callsite(mid)
      # TODO: クラス階層上、再解析が必要なところだけにする
      callsites = @callsites_by_name[mid]
      if callsites
        callsites.each do |callsite|
          add_run(callsite)
        end
      end
    end

    # global variables

    def resolve_gvar(name)
      @gvars[name] ||= Entity.new
    end

    # instance variables

    def resolve_ivar(cpath, singleton, name)
      # TODO: include はあとで考える
      dir = resolve_cpath(cpath)
      dir.ivars[singleton][name] ||= Entity.new
    end

    def subclass?(cpath1, cpath2)
      while cpath1
        return true if cpath1 == cpath2
        break if cpath1 == [:BasicObject]
        dir = resolve_cpath(cpath1)
        cpath1 = dir.superclass_cpath
      end
      return false
    end
  end
end