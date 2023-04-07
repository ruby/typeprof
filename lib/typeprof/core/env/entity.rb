module TypeProf::Core
  class VertexEntity
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

    def exist?
      !@decls.empty? || !@defs.empty?
    end
  end

  class ModuleEntity
    def initialize(cpath, outer_module, toplevel)
      @cpath = cpath

      @module_decls = Set[]
      @module_defs = Set[]
      @include_decls = Set[]
      @include_defs = Set[]

      @inner_modules = {}
      @outer_module = outer_module

      # parent modules (superclass and all modules that I include)
      @superclass = toplevel
      @included_modules = {}

      # child modules (subclasses and all modules that include me)
      @child_modules = Set[]

      @consts = {}
      @methods = { true => {}, false => {} }
      @ivars = { true => {}, false => {} }
      @type_aliases = {}

      @static_reads = {}
      @ivar_reads = Set[] # should be handled in @ivars ??
    end

    attr_reader :cpath
    attr_reader :module_decls

    attr_reader :inner_modules
    attr_reader :outer_module

    attr_reader :superclass
    attr_reader :included_modules
    attr_reader :child_modules

    attr_reader :consts
    attr_reader :methods
    attr_reader :ivars
    attr_reader :type_aliases

    attr_reader :static_reads
    attr_reader :ivar_reads

    def exist?
      !@module_decls.empty? || !@module_defs.empty?
    end

    def on_inner_modules_changed(genv, changed_cname) # TODO: accept what is a change
      @child_modules.each do |child_mod|
        next if self == child_mod # for Object
        child_mod.on_inner_modules_changed(genv, changed_cname)
      end
      if @static_reads[changed_cname]
        @static_reads[changed_cname].each do |static_read|
          genv.add_static_eval_queue(:static_read_changed, static_read)
        end
      end
    end

    def on_module_added(genv)
      return if @cpath.empty?
      unless exist?
        genv.add_static_eval_queue(:inner_modules_changed, [@outer_module, @cpath.last])
      end
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def on_module_removed(genv)
      return if @cpath.empty?
      genv.add_static_eval_queue(:parent_modules_changed, self)
      unless exist?
        genv.add_static_eval_queue(:inner_modules_changed, [@outer_module, @cpath.last])
      end
    end

    def add_module_decl(genv, decl)
      on_module_added(genv)
      @module_decls << decl
      ce = @outer_module.get_const(@cpath.empty? ? :Object : @cpath.last)
      ce.decls << decl
      ce
    end

    def remove_module_decl(genv, decl)
      @outer_module.get_const(@cpath.last).decls.delete(decl)
      @module_decls.delete(decl)
      on_module_removed(genv)
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

    def add_include_decl(genv, node)
      @include_decls << node
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def remove_include_decl(genv, node)
      @include_decls.delete(node)
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def add_include_def(genv, node)
      @include_defs << node
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def remove_include_def(genv, node)
      @include_defs.delete(node)
      genv.add_static_eval_queue(:parent_modules_changed, self)
    end

    def update_parent(genv, old_parent, new_parent_cpath)
      new_parent = new_parent_cpath ? genv.resolve_cpath(new_parent_cpath) : nil
      if old_parent != new_parent
        old_parent.child_modules.delete(self) if old_parent
        new_parent.child_modules << self if new_parent
        return [new_parent, true]
      end
      return [new_parent, false]
    end

    def on_parent_modules_changed(genv)
      any_updated = false
      new_superclass_cpath = nil

      if !@module_decls.empty?
        const_reads = nil
        @module_decls.each do |mdecl|
          if mdecl.is_a?(AST::SIG_CLASS) && mdecl.superclass_cpath
            const_reads = mdecl.static_ret
            break
          end
        end
        new_superclass_cpath = const_reads ? const_reads.last.cpath : []
      else
        const_read = nil
        @module_defs.each do |mdef|
          if mdef.is_a?(AST::CLASS) && mdef.superclass_cpath
            const_read = mdef.superclass_cpath.static_ret
            break
          end
        end
        # TODO: report multiple inconsistent superclass
        new_superclass_cpath = const_read ? const_read.cpath : []
      end

      new_superclass, updated = update_parent(genv, @superclass, new_superclass_cpath)
      if updated
        @superclass = new_superclass
        any_updated = true
      end

      @include_decls.each do |idecl|
        new_parent_cpath = idecl.static_ret.last.cpath
        new_parent, updated = update_parent(genv, @included_modules[idecl], new_parent_cpath)
        if updated
          if new_parent
            @included_modules[idecl] = new_parent
          else
            @included_modules.delete(idecl)
          end
          any_updated = true
        end
      end
      @include_defs.each do |idef|
        new_parent_cpath = idef.static_ret ? idef.static_ret.cpath : nil
        new_parent, updated = update_parent(genv, @included_modules[idef], new_parent_cpath)
        if updated
          if new_parent
            @included_modules[idef] = new_parent
          else
            @included_modules.delete(idef)
          end
          any_updated = true
        end
      end
      @included_modules.delete_if do |origin, old_mod|
        if @include_decls.include?(origin) || @include_defs.include?(origin)
          false
        else
          _new_parent, updated = update_parent(genv, old_mod, nil)
          any_updated ||= updated
          true
        end
      end

      on_ancestors_updated(genv, nil) if any_updated
    end

    def on_ancestors_updated(genv, base_mod)
      if base_mod == self
        # TODO: report circular inheritance
        return
      end
      @child_modules.each {|child_mod| child_mod.on_ancestors_updated(genv, base_mod || self) }
      @static_reads.each_value do |static_reads|
        static_reads.each do |static_read|
          genv.add_static_eval_queue(:static_read_changed, static_read)
        end
      end
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

    def get_type_alias(name)
      @type_aliases[name] ||= TypeAliasEntity.new
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

  class MethodEntity
    def initialize
      @builtin = nil
      @decls = Set[]
      @defs = Set[]
      @aliases = {}
      @callsites = Set[]
    end

    attr_reader :decls, :defs, :aliases, :callsites
    attr_accessor :builtin

    def add_decl(decl)
      @decls << decl
    end

    def remove_decl(decl)
      @decls.delete(decl)
    end

    def add_def(mdef)
      @defs << mdef
      self
    end

    def remove_def(mdef)
      @defs.delete(mdef)
    end

    def add_alias(node, old_mid)
      @aliases[node] = old_mid
    end

    def remove_alias(node)
      @aliases.delete(node) || raise
    end

    def exist?
      @builtin || !@decls.empty? || !@defs.empty? || !@aliases.empty?
    end

    def add_run_all_mdefs(genv)
      @defs.each do |mdef|
        genv.add_run(mdef)
      end
    end

    def add_run_all_callsites(genv)
      @callsites.each do |callsite|
        genv.add_run(callsite)
      end
    end
  end

  class TypeAliasEntity
    def initialize
      @decls = Set[]
    end

    attr_reader :decls

    def exist?
      !@decls.empty?
    end
  end
end