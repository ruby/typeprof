module TypeProf::Core
  class ModuleDirectory
    def initialize(cpath, toplevel)
      @cpath = cpath

      @module_decls = Set[]
      @module_defs = Set[]
      @include_defs = Set[]

      @child_modules = {}

      @superclass = toplevel
      @subclasses = Set[]
      @included_modules = {}

      @const_reads = Set[]
      @callsites = Set[]
      @ivar_reads = Set[]

      @consts = {}
      @methods = { true => {}, false => {} }
      @ivars = { true => {}, false => {} }
    end

    attr_reader :cpath

    attr_reader :module_decls
    attr_reader :module_defs
    attr_reader :include_defs

    attr_reader :child_modules

    attr_reader :superclass
    attr_reader :subclasses
    attr_reader :included_modules

    attr_reader :const_reads
    attr_reader :callsites
    attr_reader :ivar_reads

    attr_reader :consts
    attr_reader :methods
    attr_reader :ivars

    def exist?
      !@module_decls.empty? || !@module_defs.empty?
    end

    def get_method(singleton, mid)
      @methods[singleton][mid] ||= MethodEntity.new
    end

    def get_ivar(singleton, name)
      @ivars[singleton][name] ||= Entity.new
    end

    def on_child_modules_updated(genv) # TODO: accept what is a change
      @subclasses.each {|subclass| subclass.on_child_modules_updated(genv) }
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

    def on_superclass_updated(genv)
      const = nil
      # TODO: check with RBS's superclass if any
      @module_defs.each do |mdef|
        if mdef.is_a?(AST::CLASS) && mdef.superclass_cpath
          const = mdef.superclass_cpath.static_ret
          break
        end
      end

      updated = false

      # TODO: check circular class/module mix, check inconsistent superclass
      new_superclass_cpath = const ? const.cpath : []
      new_superclass = new_superclass_cpath ? genv.resolve_cpath(new_superclass_cpath) : nil
      if @superclass != new_superclass
        @superclass.subclasses.delete(self) if @superclass
        @superclass = new_superclass
        @superclass.subclasses << self if @superclass
        updated = true
      end

      all_args = Set[]
      @include_defs.each do |idef|
        idef.args.each do |arg|
          if arg.is_a?(AST::ConstNode) && arg.static_ret
            all_args << arg
            new_mod_cpath = arg.static_ret
            new_mod_cpath = new_mod_cpath ? new_mod_cpath.cpath : nil
            new_mod = new_mod_cpath ? genv.resolve_cpath(new_mod_cpath) : nil
            old_mod = @included_modules[arg]
            if old_mod != new_mod
              old_mod.subclasses.delete(self) if old_mod
              old_mod = @included_modules[arg] = new_mod
              new_mod.subclasses << self if new_mod
              updated = true
            end
          end
        end
      end
      @included_modules.to_a.each do |arg, old_mod|
        if arg.is_a?(AST::ConstNode) && !all_args.include?(arg)
          old_mod.subclasses.delete(self) if old_mod
          @included_modules.delete(arg)
        end
      end

      on_ancestors_updated(genv) if updated
    end

    def on_ancestors_updated(genv)
      @subclasses.each {|subclass| subclass.on_ancestors_updated(genv) }
      @const_reads.each {|const_read| genv.const_read_changed(const_read) }
      @callsites.each {|callsite| genv.add_run(callsite) }
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

    def add_run_all_callsites(genv)
      traverse_subclasses do |subclass_dir|
        subclass_dir.callsites.each do |callsite|
          genv.add_run(callsite)
        end
      end
    end

    def traverse_subclasses(&blk)
      yield self
      @subclasses.each do |subclass|
        subclass.traverse_subclasses(&blk)
      end
    end

    def get_vertexes_and_boxes(vtxs)
      @child_modules.each_value do |dir|
        next if self.equal?(dir) # for Object
        dir.get_vertexes_and_boxes(vtxs)
      end
      @consts.each_value do |cdef|
        vtxs << cdef.vtx
      end
    end
  end
end