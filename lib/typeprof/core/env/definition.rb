module TypeProf::Core
  class ModuleEntity
    def initialize(cpath, outer_module, toplevel)
      @cpath = cpath

      @module_decls = Set[]
      @module_defs = Set[]
      @include_defs = Set[]

      @inner_modules = {}
      @outer_module = outer_module

      # parent modules (superclass and all modules that I include)
      @superclass = toplevel
      @superclass_fixed = false
      @included_modules = {}

      # child modules (subclasses and all modules that include me)
      @child_modules = Set[]

      @consts = {}
      @methods = { true => {}, false => {} }
      @ivars = { true => {}, false => {} }

      @const_reads = Set[]
      @ivar_reads = Set[] # should be handled in @ivars ??
    end

    attr_reader :cpath

    attr_reader :inner_modules
    attr_reader :outer_module

    attr_reader :superclass
    attr_reader :included_modules
    attr_reader :child_modules

    attr_reader :consts
    attr_reader :methods
    attr_reader :ivars

    attr_reader :const_reads
    attr_reader :callsites
    attr_reader :ivar_reads

    def exist?
      !@module_decls.empty? || !@module_defs.empty?
    end

    def on_inner_modules_changed(genv) # TODO: accept what is a change
      @child_modules.each do |child_mod|
        next if self == child_mod # for Object
        child_mod.on_inner_modules_changed(genv)
      end
      @const_reads.each {|const_read| genv.add_static_eval_queue(:const_read_changed, const_read) }
    end

    def on_module_added(genv)
      unless exist?
        genv.add_static_eval_queue(:inner_modules_changed, @outer_module)
      end
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def on_module_removed(genv)
      genv.add_static_eval_queue(:parent_modules_changed, self)
      unless exist?
        genv.add_static_eval_queue(:inner_modules_changed, @outer_module)
      end
    end

    def add_module_decl(genv, decl)
      on_module_added(genv)
      @module_decls << decl
      ce = @outer_module.get_const(@cpath.last)
      ce.decls << decl
      ce
    end

    def remove_module_decl(genv, decl)
      @outer_module.get_const(@cpath.last).decls.delete(decl)
      @module_decls.delete(decl)
      on_module_removed(genv)
    end

    def set_superclass(mod) # for RBS
      @superclass = mod
      @superclass_fixed = true
    end

    def add_module_def(genv, node)
      on_module_added(genv)
      @module_defs << node
      ce = @outer_module.get_const(@cpath.last)
      ce.defs << node
      ce
    end

    def remove_module_def(genv, node)
      @outer_module.get_const(@cpath.last).defs.delete(node)
      @module_defs.delete(node)
      on_module_removed(genv)
    end

    def add_include_decl(origin, mod) # for RBS
      @included_modules[origin] = mod
    end

    def remove_include_decl(origin)
      @included_modules.delete(origin)
    end

    def add_include_def(genv, node)
      @include_defs << node
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def remove_include_def(genv, node)
      @include_defs.delete(node)
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def update_parent(genv, old_parent, const_read, default)
      new_parent_cpath = const_read ? const_read.cpath : default
      new_parent = new_parent_cpath ? genv.resolve_cpath(new_parent_cpath) : nil
      if old_parent != new_parent
        old_parent.child_modules.delete(self) if old_parent
        new_parent.child_modules << self if new_parent
        return [new_parent, true]
      end
      return [new_parent, false]
    end

    def on_parent_modules_changed(genv)
      if @superclass_fixed
        return @superclass
      end

      const_read = nil
      # TODO: check with RBS's superclass if any
      @module_defs.each do |mdef|
        if mdef.is_a?(AST::CLASS) && mdef.superclass_cpath
          const_read = mdef.superclass_cpath.static_ret
          break
        end
      end

      any_updated = false

      # TODO: report multiple inconsistent superclass

      new_superclass, updated = update_parent(genv, @superclass, const_read, [])
      if updated
        @superclass = new_superclass
        any_updated = true
      end

      @include_defs.each do |idef|
        new_parent, updated = update_parent(genv, @included_modules[idef], idef.static_ret, nil)
        if updated
          if new_parent
            @included_modules[idef] = new_parent
          else
            @included_modules.delete(idef)
          end
          any_updated = true
        end
      end
      @included_modules.delete_if do |idef, old_mod|
        next if @include_defs.include?(idef)
        _new_parent, updated = update_parent(genv, @included_modules[idef], nil, nil)
        any_updated ||= updated
        true
      end

      on_ancestors_updated(genv, nil) if any_updated
    end

    def on_ancestors_updated(genv, base_mod)
      if base_mod == self
        # TODO: report circular inheritance
        return
      end
      @child_modules.each {|child_mod| child_mod.on_ancestors_updated(genv, base_mod || self) }
      @const_reads.each {|const_read| genv.add_static_eval_queue(:const_read_changed, const_read) }
      @methods.each do |_, methods|
        methods.each_value do |me|
          me.callsites.each do |callsite|
            genv.add_run(callsite)
          end
        end
      end
      @ivar_reads.each {|ivar_read| genv.add_run(ivar_read) }
    end

    def each_descendant(base_mod = nil, &blk)
      return if base_mod == self
      yield self
      @child_modules.each do |child_mod|
        child_mod.each_descendant(base_mod || self, &blk)
      end
    end

    def get_const(cname)
      @consts[cname] ||= VertexEntity.new
    end

    def get_method(singleton, mid)
      @methods[singleton][mid] ||= MethodEntity.new
    end

    def get_ivar(singleton, name)
      @ivars[singleton][name] ||= VertexEntity.new
    end

    def get_vertexes(vtxs)
      @inner_modules.each_value do |mod|
        next if self.equal?(mod) # for Object
        mod.get_vertexes(vtxs)
      end
      @consts.each_value do |cdef|
        vtxs << cdef.vtx
      end
    end

    def show_cpath
      @cpath.empty? ? "Object" : @cpath.join("::" )
    end
  end
end