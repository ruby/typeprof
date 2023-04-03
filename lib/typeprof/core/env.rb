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

  class GlobalEnv
    def initialize(rbs_builder)
      @static_eval_queue = {
        child_modules_changed: [],
        const_read_changed: [],
        parent_modules_changed: [],
      }
      @const_read_changed = []

      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleDirectory.new([], nil)
      @toplevel.child_modules[:Object] = @toplevel
      @mod_basic_object = resolve_cpath([:BasicObject])
      @mod_class = resolve_cpath([:Class])
      @mod_module = resolve_cpath([:Module])

      @gvars = {}

      @rbs_builder = rbs_builder

      @run_count = 0
    end

    attr_accessor :run_count

    def get_superclass(dir, singleton)
      if dir == @mod_basic_object
        if singleton
          return [@mod_class, false]
        else
          return nil
        end
      else
        dir = dir.superclass
        if dir
          return [dir, singleton]
        else
          return [@mod_module, false]
        end
      end
    end

    attr_reader :rbs_builder

    def child_modules_changed(cpath)
      @child_modules_changed << cpath
    end

    def add_static_eval_queue(change_type, arg)
      @static_eval_queue[change_type] << arg
    end

    def const_read_changed(cpath)
      @static_eval_queue[:const_read_changed] << cpath
    end

    def define_all
      update = true
      while update
        update = false
        @static_eval_queue.each do |change_type, queue|
          next if queue.empty?
          update = true
          arg = queue.shift
          case change_type
          when :child_modules_changed
            resolve_cpath(arg).on_child_modules_changed(self)
          when :const_read_changed
            case arg
            when BaseConstRead
              arg.on_scope_updated(self)
            when ScopedConstRead
              arg.on_cbase_updated(self)
            end
          when :parent_module_changed
            resolve_cpath(arg).on_parent_module_changed(self)
          end
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
      run_count = 0
      until @run_queue.empty?
        obj = @run_queue.shift
        @run_queue_set.delete(obj)
        unless obj.destroyed
          run_count += 1
          obj.run(self)
        end
      end
      @run_count += run_count
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

    # constants

    def resolve_const(cpath)
      dir = resolve_cpath(cpath[0..-2])
      dir.consts[cpath[-1]] ||= VertexEntity.new
    end

    def resolve_method(cpath, singleton, mid)
      dir = resolve_cpath(cpath)
      dir.get_method(singleton, mid)
    end

    def resolve_gvar(name)
      @gvars[name] ||= VertexEntity.new
    end

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