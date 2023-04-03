module TypeProf::Core
  class ModuleDirectory
    def initialize(cpath, toplevel)
      @cpath = cpath

      @module_decls = Set[]
      @module_defs = Set[]
      @include_defs = Set[]

      @inner_modules = {}

      @superclass = toplevel
      @subclasses = Set[]
      @included_modules = {}

      @consts = {}
      @methods = { true => {}, false => {} }
      @ivars = { true => {}, false => {} }

      @const_reads = Set[]
      @callsites = { true => {}, false => {} }
      @ivar_reads = Set[]
    end

    attr_reader :cpath

    attr_reader :module_decls
    attr_reader :module_defs
    attr_reader :include_defs

    attr_reader :inner_modules

    attr_reader :superclass
    attr_reader :subclasses
    attr_reader :included_modules

    attr_reader :consts
    attr_reader :methods
    attr_reader :ivars

    attr_reader :const_reads
    attr_reader :callsites
    attr_reader :ivar_reads

    def exist?
      !@module_decls.empty? || !@module_defs.empty?
    end

    def get_method(singleton, mid)
      @methods[singleton][mid] ||= MethodEntity.new
    end

    def get_ivar(singleton, name)
      @ivars[singleton][name] ||= VertexEntity.new
    end

    def on_inner_modules_changed(genv) # TODO: accept what is a change
      @subclasses.each {|subclass| subclass.on_inner_modules_changed(genv) }
      @const_reads.each {|const_read| genv.const_read_changed(const_read) }
    end

    def set_superclass(dir) # for RBS
      @superclass = dir
    end

    def add_included_module(origin, dir) # for RBS
      @included_modules[origin] = dir
    end

    def remove_included_module(origin)
      @included_modules.delete(origin)
    end

    def add_module_def(genv, node)
      if @module_defs.empty?
        genv.add_static_eval_queue(:inner_modules_changed, @cpath[0..-2])
      end
      @module_defs << node
      genv.add_static_eval_queue(:parent_modules_changed, @cpath)
    end

    def remove_module_def(genv, node)
      @module_defs.delete(node)
      genv.add_static_eval_queue(:parent_modules_changed, @cpath)
      if @module_defs.empty?
        genv.add_static_eval_queue(:inner_modules_changed, @cpath[0..-2])
      end
    end

    def add_include_def(genv, node)
      @include_defs << node
    end

    def remove_include_def(genv, node)
      @include_defs.delete(node)
    end

    def update_parent(genv, old_parent, const_read, default)
      new_parent_cpath = const_read ? const_read.cpath : default
      new_parent = new_parent_cpath ? genv.resolve_cpath(new_parent_cpath) : nil
      if old_parent != new_parent
        old_parent.subclasses.delete(self) if old_parent
        new_parent.subclasses << self if new_parent
        return [new_parent, true]
      end
      return [new_parent, false]
    end

    def on_parent_module_changed(genv)
      const_read = nil
      # TODO: check with RBS's superclass if any
      @module_defs.each do |mdef|
        if mdef.is_a?(AST::CLASS) && mdef.superclass_cpath
          const_read = mdef.superclass_cpath.static_ret
          break
        end
      end
      # TODO: report if it has multiple inconsistent superclasses:
      # class C<A;end; class C<B;end # A!=B

      any_updated = false

      # TODO: check circular class/module mix, check inconsistent superclass

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
        new_parent, updated = update_parent(genv, @included_modules[idef], nil, nil)
        if updated
          if new_parent
            @included_modules[idef] = new_parent
          else
            @included_modules.delete(idef)
          end
          any_updated = true
        end
      end

      on_ancestors_updated(genv) if any_updated
    end

    def on_ancestors_updated(genv)
      @subclasses.each {|subclass| subclass.on_ancestors_updated(genv) }
      @const_reads.each {|const_read| genv.const_read_changed(const_read) }
      @callsites.each do |_, callsites|
        callsites.each_value do |callsites|
          callsites.each do |callsite|
            genv.add_run(callsite)
          end
        end
      end
      @ivar_reads.each {|ivar_read| genv.add_run(ivar_read) }
    end

    def each_subclass_of_ivar(singleton, name, &blk)
      sub_e = @ivars[singleton][name]
      if sub_e
        yield sub_e, @cpath
      else
        @subclasses.each do |subclass|
          subclass.each_subclass_of_ivar(singleton, name, &blk)
        end
      end
    end

    def add_depended_method_entity(singleton, mid, target)
      @callsites[singleton] ||= {}
      @callsites[singleton][mid] ||= Set[]
      @callsites[singleton][mid] << target
    end

    def remove_depended_method_entity(singleton, mid, target)
      @callsites[singleton][mid].delete(target)
    end

    def add_run_all_callsites(genv, singleton, mid)
      callsites = @callsites[singleton][mid]
      callsites.each {|callsite| genv.add_run(callsite) } if callsites
    end

    def traverse_subclasses(&blk)
      yield self
      @subclasses.each do |subclass|
        subclass.traverse_subclasses(&blk)
      end
    end

    def get_vertexes_and_boxes(vtxs)
      @inner_modules.each_value do |dir|
        next if self.equal?(dir) # for Object
        dir.get_vertexes_and_boxes(vtxs)
      end
      @consts.each_value do |cdef|
        vtxs << cdef.vtx
      end
    end
  end
end