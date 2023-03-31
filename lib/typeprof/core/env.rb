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
      @child_modules_changed = []
      @const_read_changed = []

      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleDirectory.new([], nil)
      @toplevel.child_modules[:Object] = @toplevel

      @gvars = {}

      @rbs_builder = rbs_builder

      @callsites_by_name = {}
      @ivreadsites_by_name = {}
    end

    attr_reader :rbs_builder

    def child_modules_changed(cpath)
      @child_modules_changed << cpath
    end

    def const_read_changed(cpath)
      @const_read_changed << cpath
    end

    def define_all
      @child_modules_changed.uniq.each do |v|
        resolve_cpath(v).on_child_modules_updated(self)
      end
      @child_modules_changed.clear

      until @const_read_changed.empty?
        # I wonder if this loop can ever loop infinitely...
        v = @const_read_changed.shift
        case v
        when BaseConstRead
          v.on_scope_updated(self)
        when ScopedConstRead
          v.on_cbase_updated(self)
        else
          raise
        end
      end

      # TODO: check circular inheritance
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
        dir = dir.child_modules[cname] ||= ModuleDirectory.new(dir.cpath + [cname], @toplevel)
      end
      dir
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
      @const_read_changed << const_read
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
      dir.get_method(singleton, mid)
    end

    # global variables

    def resolve_gvar(name)
      @gvars[name] ||= Entity.new
    end

    # instance variables

    def resolve_ivar(cpath, singleton, name)
      # TODO: include はあとで考える
      dir = resolve_cpath(cpath)
      dir.get_ivar(singleton, name)
    end

    def subclass?(cpath1, cpath2)
      dir = resolve_cpath(cpath1)
      while true
        return true if dir.cpath == cpath2
        break if dir.cpath == [:BasicObject]
        dir = dir.superclass
      end
      return false
    end
  end
end