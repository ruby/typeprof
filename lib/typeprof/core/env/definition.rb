module TypeProf::Core
  class ModuleDirectory
    def initialize(cpath)
      @cpath = cpath

      # use Entity?
      @module_decls = Set[]
      @module_defs = Set[]
      @child_modules = {}

      @superclass_cpath = []
      @subclasses = Set[]
      @const_reads = Set[]
      @ivar_reads = Set[]

      @child_consts = {}

      @methods = { true => {}, false => {} }
      @ivars = { true => {}, false => {} }

      @singleton_methods = {}
      @instance_methods = {}
      @include_module_cpaths = Set[]
    end

    attr_reader :cpath
    attr_reader :module_decls
    attr_reader :module_defs
    attr_reader :child_modules
    attr_reader :superclass_cpath
    attr_reader :subclasses
    attr_reader :const_reads
    attr_reader :ivar_reads

    attr_reader :child_consts
    attr_reader :methods
    attr_reader :ivars
    attr_reader :include_module_cpaths

    def exist?
      !@module_decls.empty? || !@module_defs.empty?
    end

    def methods_old(singleton)
      singleton ? @singleton_methods : @instance_methods
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
        on_ancestors_updated(genv)
      end
    end

    def on_ancestors_updated(genv)
      @subclasses.each {|subclass| subclass.on_ancestors_updated(genv) }
      @const_reads.dup.each {|const_read| const_read.on_scope_updated(genv) }
      @ivar_reads.dup.each {|ivar_read| genv.add_run(ivar_read) }
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

  class MethodEntity
    def initialize
      @decls = Set[]
      @defs = Set[]
      @aliases = Set[]
    end

    attr_reader :decls, :defs, :aliases

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

    def add_alias(mid)
      @aliases << mid
    end

    def remove_alias(mid)
      @aliases.delete(mid)
    end

    def exist?
      !@decls.empty? || !@defs.empty? || !@aliases.empty?
    end
  end

  class MethodDecl
  end
end