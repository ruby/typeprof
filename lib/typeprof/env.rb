module TypeProf
  class ModuleDirectory
    def initialize
      @module_defs = Set[]
      @child_modules = {}
      @superclass_cpath = nil

      @consts = {}
      @singleton_methods = {}
      @instance_methods = {}
    end

    def set_superclass_path(cpath)
      @superclass_path = cpath
    end

    attr_reader :module_defs, :child_modules
    attr_accessor :superclass_cpath
    attr_reader :consts

    def methods(singleton)
      singleton ? @singleton_methods : @instance_methods
    end
  end

  class Entity
    def initialize
      @decls = Set[]
      @defs = Set[]
    end

    attr_reader :decls, :defs
  end

  class ConstDecl
    def initialize(cpath, cname, type)
      @cpath = cpath
      @cname = cname
      @type = type
    end

    attr_reader :cpath, :cname, :type
  end

  class ConstDef
    def initialize(cpath, cname, node, val)
      @cpath = cpath
      @cname = cname
      @node = node
      @val = val
    end

    attr_reader :cpath, :cname, :node, :val
  end

  class MethodDecl
    def initialize(cpath, singleton, mid, rbs_member)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      @rbs_member = rbs_member
      @builtin = nil
    end

    attr_reader :cpath, :singleton, :mid, :rbs_member, :builtin

    def resolve_overloads(genv, a_arg) # TODO: only one argument is supported!
      if @builtin
        return @builtin[genv, a_arg]
      end
      ret_types = []
      @rbs_member.overloads.each do |overload|
        func = overload.method_type.type
        # func.optional_keywords
        # func.optional_positionals
        # func.required_keywords
        # func.rest_keywords
        # func.rest_positionals
        # func.trailing_positionals
        # TODO: only one argument!
        f_arg = func.required_positionals.first
        f_arg = Signatures.type(genv, f_arg.type)
        if a_arg.types.key?(f_arg) # TODO: type consistency
          ret_types << Signatures.type(genv, func.return_type)
        end
      end
      ret_types
    end

    def set_builtin(&blk)
      @builtin = blk
    end

    def inspect
      "#<MethodDecl ...>"
    end
  end

  class MethodDef
    def initialize(cpath, singleton, mid, node, arg, block, ret)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      @node = node
      @arg = arg
      @block = block
      @ret = ret
    end

    attr_reader :cpath, :singleton, :mid, :node, :arg, :block, :ret

    def show
      block_show = []
      # just for debug
      if @block
        @block.types.each_key do |ty|
          case ty
          when Type::Proc
            block_show << "{ (#{ ty.block.arg.show }) -> #{ ty.block.ret.show } }"
          else
            puts "???"
          end
        end
      end
      s = "(#{ @arg.show })"
      s << " (#{ block_show.join(" | ") })" unless block_show.empty?
      s << " -> #{ @ret.show }"
    end
  end

  class BlockDef
    def initialize(node, arg, ret)
      @node = node
      @arg = arg
      @ret = ret
    end

    attr_reader :node, :arg, :ret
  end

  class GlobalEnv
    def initialize
      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleDirectory.new

      loader = RBS::EnvironmentLoader.new
      @rbs_env = RBS::Environment.from_loader(loader).resolve_type_names
      @rbs_builder = RBS::DefinitionBuilder.new(env: rbs_env)

      @callsites_by_name = {}
      @readsites_by_name = {}
    end

    attr_reader :rbs_env, :rbs_builder

    def add_run(obj)
      unless @run_queue_set.include?(obj)
        @run_queue << obj
        @run_queue_set << obj
      end
    end

    def run_all
      until @run_queue.empty?
        obj = @run_queue.shift
        @run_queue_set.delete(obj)
        obj.run(self)
      end
    end

    def resolve_cpath(cpath)
      dir = @toplevel
      cpath.each do |cname|
        dir = dir.child_modules[cname] ||= ModuleDirectory.new
      end
      dir
    end

    def add_module(cpath, mod_def)
      dir = resolve_cpath(cpath)
      dir.module_defs << mod_def
      dir
    end

    def remove_module(cpath, mod_def)
      dir = resolve_cpath(cpath)
      dir.module_defs.delete(mod_def)
    end

    def set_superclass(cpath, superclass_cpath)
      dir = resolve_cpath(cpath)
      dir.superclass_cpath = superclass_cpath
    end

    def get_const_entity(cpath, cname)
      dir = resolve_cpath(cpath)
      dir.consts[cname] ||= Entity.new
    end

    def add_const_decl(mdecl)
      e = get_const_entity(mdecl.cpath, mdecl.cname)
      e.decls << mdecl
    end

    def add_const_def(cdef)
      e = get_const_entity(cdef.cpath, cdef.cname)
      e.defs << cdef

      run_readsite(cdef.cname)
    end

    def remove_const_def(cdef)
      dir = resolve_cpath(cdef.cpath)
      dir.consts[cdef.cname].defs.delete(cdef)

      run_readsite(cdef.cname)
    end

    def resolve_const(cpath, cname)
      while cpath
        dir = resolve_cpath(cpath)
        e = dir.consts[cname]
        if e
          return e.decls unless e.decls.empty?
          return e.defs unless e.defs.empty?
        end
        cpath = dir.superclass_cpath
        break if cpath == [:Object]
      end
    end

    def get_method_entity(cpath, singleton, mid)
      dir = resolve_cpath(cpath)
      dir.methods(singleton)[mid] ||= Entity.new
    end

    def add_method_decl(mdecl)
      e = get_method_entity(mdecl.cpath, mdecl.singleton, mdecl.mid)
      e.decls << mdecl
    end

    # TODO: remove_method_decl

    def add_method_def(mdef)
      e = get_method_entity(mdef.cpath, mdef.singleton, mdef.mid)
      e.defs << mdef

      run_callsite(mdef.mid)
    end

    def remove_method_def(mdef)
      dir = resolve_cpath(mdef.cpath)
      dir.methods(mdef.singleton)[mdef.mid].defs.delete(mdef)

      run_callsite(mdef.mid)
    end

    def resolve_method(cpath, singleton, mid)
      while true
        dir = resolve_cpath(cpath)
        e = dir.methods(singleton)[mid]
        if e
          return e.decls unless e.decls.empty?
          return e.defs unless e.defs.empty?
        end
        if cpath == [:BasicObject]
          if singleton
            singleton = false
            cpath = [:Class]
          else
            return nil
          end
        else
          cpath = dir.superclass_cpath
        end
      end
    end

    def add_readsite(readsite)
      (@readsites_by_name[readsite.cname] ||= Set[]) << readsite
      add_run(readsite)
    end

    def remove_readsite(readsite)
      @readsites_by_name[readsite.cname].delete(readsite)
    end

    def run_callsite(mid)
      # TODO: クラス階層上、再解析が必要なところだけにする
      callsites = @callsites_by_name[mid]
      if callsites
        callsites.each do |callsite|
          add_run(callsite)
        end
      end
    end

    def add_callsite(callsite)
      (@callsites_by_name[callsite.mid] ||= Set[]) << callsite
      add_run(callsite)
    end

    def remove_callsite(callsite)
      @callsites_by_name[callsite.mid].delete(callsite)
    end

    def run_readsite(cname)
      readsites = @readsites_by_name[cname]
      if readsites
        readsites.each do |readsite|
          add_run(readsite)
        end
      end
    end
  end
end