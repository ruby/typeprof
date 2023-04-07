module TypeProf::Core
  class GlobalEnv
    def initialize
      @static_eval_queue = []

      @run_queue = []
      @run_queue_set = Set[]

      @mod_object = ModuleEntity.new([], nil, nil)
      @mod_object.inner_modules[:Object] = @mod_object
      @mod_object.instance_variable_set(:@outer_module, @mod_object)
      @mod_basic_object = resolve_cpath([:BasicObject])
      @mod_object.instance_variable_set(:@superclass, @mod_basic_object)
      @mod_class = resolve_cpath([:Class])
      @mod_module = resolve_cpath([:Module])

      @gvars = {}
      @mod_ary = resolve_cpath([:Array])
      @mod_hash = resolve_cpath([:Hash])
      @mod_range = resolve_cpath([:Range])

      @obj_type = Type::Instance.new(resolve_cpath([:Object]), [])
      @nil_type = Type::Instance.new(resolve_cpath([:NilClass]), [])
      @true_type = Type::Instance.new(resolve_cpath([:TrueClass]), [])
      @false_type = Type::Instance.new(resolve_cpath([:FalseClass]), [])
      @str_type = Type::Instance.new(resolve_cpath([:String]), [])
      @int_type = Type::Instance.new(resolve_cpath([:Integer]), [])
      @float_type = Type::Instance.new(resolve_cpath([:Float]), [])
      @proc_type = Type::Instance.new(resolve_cpath([:Proc]), [])
      @symbol_type = Type::Instance.new(resolve_cpath([:Symbol]), [])
      @set_type = Type::Instance.new(resolve_cpath([:Set]), [])
      @regexp_type = Type::Instance.new(resolve_cpath([:Regexp]), [])

      @run_count = 0
    end

    attr_reader :obj_type, :nil_type, :true_type, :false_type, :str_type, :int_type, :float_type
    attr_reader :proc_type, :symbol_type, :set_type, :regexp_type

    def gen_ary_type(elem_vtx)
      Type::Instance.new(@mod_ary, [elem_vtx])
    end

    def gen_hash_type(key_vtx, val_vtx)
      Type::Instance.new(@mod_hash, [key_vtx, val_vtx])
    end

    def gen_range_type(elem_vtx)
      Type::Instance.new(@mod_range, [elem_vtx])
    end

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

    def add_static_eval_queue(change_type, arg)
      @static_eval_queue << [change_type, arg]
    end

    def define_all
      until @static_eval_queue.empty?
        change_type, arg = @static_eval_queue.shift
        case change_type
        when :inner_modules_changed
          arg[0].on_inner_modules_changed(self, arg[1])
        when :static_read_changed
          case arg
          when BaseStaticRead
            arg.on_scope_updated(self)
          when ScopedStaticRead
            arg.on_cbase_updated(self)
          else
            raise
          end
        when :parent_modules_changed
          arg.on_parent_modules_changed(self)
        else
          raise change_type.to_s
        end
      end
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
      @mod_object.get_vertexes(vtxs)
      @gvars.each_value do |gvar_entity|
        vtxs << gvar_entity.vtx
      end
    end

    # classes and modules

    def resolve_cpath(cpath)
      mod = @mod_object
      raise unless cpath # annotation
      cpath.each do |cname|
        mod = mod.inner_modules[cname] ||= ModuleEntity.new(mod.cpath + [cname], mod, @mod_object)
      end
      mod
    end

    # constants

    def resolve_const(cpath)
      mod = resolve_cpath(cpath[0..-2])
      mod.get_const(cpath[-1])
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

    def resolve_type_alias(cpath, name)
      # TODO: include はあとで考える
      mod = resolve_cpath(cpath)
      mod.get_type_alias(name)
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

    def load_core_rbs(raw_decls)
      lenv = LocalEnv.new(nil, CRef::Toplevel, {})
      decls = raw_decls.map do |raw_decl|
        AST.create_rbs_decl(raw_decl, lenv)
      end.compact

      # Loading frequently used modules first will reduces constant resolution
      # which makes loading faster :-)
      critical_modules = [
        decls.find {|decl| decl.cpath == [:Object] },
        decls.find {|decl| decl.cpath == [:Module] },
        decls.find {|decl| decl.cpath == [:Numeric] },
        decls.find {|decl| decl.cpath == [:Integer] },
        decls.find {|decl| decl.cpath == [:String] },
        decls.find {|decl| decl.cpath == [:Array] },
        decls.find {|decl| decl.cpath == [:Hash] },
        decls.find {|decl| decl.cpath == [:Enumerator] },
      ]
      decls = critical_modules + (decls - critical_modules)

      decls.each {|decl| decl.define(self) }
      define_all
      decls.each {|decl| decl.install(self) }
      run_all
    end
  end

  class LocalEnv
    def initialize(path, cref, locals)
      @path = path
      @cref = cref
      @locals = locals
      @filters = {}
    end

    attr_reader :path, :cref, :locals

    def new_var(name, node)
      @locals[name] = Vertex.new("var:#{ name }", node)
    end

    def set_var(name, vtx)
      @locals[name] = vtx
    end

    def get_var(name)
      @locals[name] || raise
    end

    def push_read_filter(name, type)
      (@filters[name] ||= []) << type
    end

    def pop_read_filter(name)
      (@filters[name] ||= []).pop
    end

    def apply_read_filter(genv, node, name, vtx)
      if @filters[name] && !@filters[name].empty?
        case @filters[name].last
        when :non_nil
          return NilFilter.new(genv, node, vtx, false).next_vtx
        end
      end
      vtx
    end
  end

  class CRef
    def initialize(cpath, singleton, outer)
      @cpath = cpath
      @singleton = singleton
      @outer = outer
    end

    attr_reader :cpath, :singleton, :outer

    def extend(cpath, singleton)
      CRef.new(cpath, singleton, self)
    end

    def get_self(genv)
      if @singleton
        Type::Singleton.new(genv.resolve_cpath(@cpath || []))
      else
        Type::Instance.new(genv.resolve_cpath(@cpath || []), [])
      end
    end

    Toplevel = self.new([], false, nil)
  end
end