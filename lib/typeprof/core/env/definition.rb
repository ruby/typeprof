module TypeProf::Core
  class ModuleDirectory
    def initialize(cpath)
      @cpath = cpath

      @module_decls = Set[]
      @module_defs = Set[]
      @child_modules = {}

      @superclass_cpath = []
      @subclasses = Set[]
      @const_reads = Set[]

      @child_consts = {}

      @singleton_methods = {}
      @instance_methods = {}
      @include_module_cpaths = Set[]

      @singleton_ivars = {}
      @instance_ivars = {}
    end

    attr_reader :cpath
    attr_reader :module_decls
    attr_reader :module_defs
    attr_reader :child_modules
    attr_reader :child_consts
    attr_reader :superclass_cpath
    attr_reader :subclasses
    attr_reader :const_reads
    attr_reader :include_module_cpaths

    def methods(singleton)
      singleton ? @singleton_methods : @instance_methods
    end

    def ivars(singleton)
      singleton ? @singleton_ivars : @instance_ivars
    end

    def on_child_modules_updated(genv) # TODO: accept what is a change
      @subclasses.each {|subclass| subclass.on_child_modules_updated(genv) }
      @const_reads.dup.each do |const_read|
        case const_read
        when BaseConstRead
          const_read.on_scope_updated(genv)
        when ScopedConstRead
          const_read.on_cbase_updated(genv)
        else
          raise
        end
      end
    end

    def set_superclass_cpath(cpath) # for RBS
      @superclass_cpath = cpath
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
      # TODO: check circular class/module mix, check inconsistent superclass
      superclass_cpath = const ? const.cpath : []
      if superclass_cpath != @superclass_cpath
        genv.resolve_cpath(@superclass_cpath).subclasses.delete(self) if @superclass_cpath
        @superclass_cpath = superclass_cpath
        genv.resolve_cpath(@superclass_cpath).subclasses << self if @superclass_cpath
        @subclasses.each {|subclass| subclass.on_superclass_updated(genv) }
        @const_reads.dup.each {|const_read| const_read.on_scope_updated(genv) }
      end
    end

    def get_vertexes_and_boxes(vtxs)
      @child_modules.each_value do |dir|
        next if self.equal?(dir) # for Object
        dir.get_vertexes_and_boxes(vtxs)
      end
      @child_consts.each_value do |cdef|
        vtxs << cdef.vtx
      end
    end
  end

end