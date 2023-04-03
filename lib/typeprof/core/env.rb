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
      @rbs_builder = rbs_builder

      @static_eval_queue = {
        inner_modules_changed: [],
        const_read_changed: [],
        parent_modules_changed: [],
      }
      @const_read_changed = []

      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleEntity.new([], nil)
      @toplevel.inner_modules[:Object] = @toplevel
      @mod_basic_object = resolve_cpath([:BasicObject])
      @mod_class = resolve_cpath([:Class])
      @mod_module = resolve_cpath([:Module])

      @gvars = {}

      @obj_type = Type::Instance.new([:Object])
      @nil_type = Type::Instance.new([:NilClass])
      @true_type = Type::Instance.new([:TrueClass])
      @false_type = Type::Instance.new([:FalseClass])
      @str_type = Type::Instance.new([:String])
      @int_type = Type::Instance.new([:Integer])
      @float_type = Type::Instance.new([:Float])
      @ary_type = Type::Instance.new([:Array])
      @hash_type = Type::Instance.new([:Hash])
      @range_type = Type::Instance.new([:Range])

      @run_count = 0
    end

    attr_reader :obj_type, :nil_type, :true_type, :false_type, :str_type, :int_type, :float_type, :ary_type, :hash_type, :range_type

    attr_accessor :run_count

    def get_superclass(mod, singleton)
      if mod == @mod_basic_object
        if singleton
          return [@mod_class, false]
        else
          return nil
        end
      else
        mod = mod.superclass
        if mod
          return [mod, singleton]
        else
          return [@mod_module, false]
        end
      end
    end

    attr_reader :rbs_builder

    def inner_modules_changed(cpath)
      @inner_modules_changed << cpath
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
          when :inner_modules_changed
            resolve_cpath(arg).on_inner_modules_changed(self)
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
    def get_vertexes(vtxs)
      @toplevel.get_vertexes(vtxs)
      @gvars.each_value do |gvar_entity|
        vtxs << gvar_entity.vtx
      end
    end

    # classes and modules

    def resolve_cpath(cpath)
      mod = @toplevel
      raise unless cpath # annotation
      cpath.each do |cname|
        mod = mod.inner_modules[cname] ||= ModuleEntity.new(mod.cpath + [cname], @toplevel)
      end
      mod
    end

    # constants

    def resolve_const(cpath)
      mod = resolve_cpath(cpath[0..-2])
      mod.consts[cpath[-1]] ||= VertexEntity.new
    end

    def resolve_method(cpath, singleton, mid)
      mod = resolve_cpath(cpath)
      mod.get_method(singleton, mid)
    end

    def resolve_gvar(name)
      @gvars[name] ||= VertexEntity.new
    end

    def resolve_ivar(cpath, singleton, name)
      # TODO: include はあとで考える
      mod = resolve_cpath(cpath)
      mod.get_ivar(singleton, name)
    end

    def subclass?(cpath1, cpath2)
      mod = resolve_cpath(cpath1)
      while true
        return true if mod.cpath == cpath2
        break if mod.cpath == [:BasicObject]
        mod = mod.superclass
      end
      return false
    end
  end
end