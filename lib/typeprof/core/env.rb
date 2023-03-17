module TypeProf::Core
  class ModuleDirectory
    def initialize
      @module_defs = Set[]
      @child_modules = {}
      @superclass_cpath = nil

      @consts = {}
      @singleton_methods = {}
      @instance_methods = {}
      @singleton_ivars = {}
      @instance_ivars = {}
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

    def ivars(singleton)
      singleton ? @singleton_ivars : @instance_ivars
    end
  end

  class Entity
    def initialize
      @decls = Set[]
      @defs = Set[]
    end

    attr_reader :decls, :defs
  end

  class ConstEntry
    def initialize(cpath, cname)
      @cpath = cpath
      @cname = cname
    end

    attr_reader :cpath, :cname
  end

  class ConstDecl < ConstEntry
    def initialize(cpath, cname, type)
      super(cpath, cname)
      @type = type
    end

    attr_reader :type
  end

  class ConstDef < ConstEntry
    def initialize(cpath, cname, node, val)
      super(cpath, cname)
      @node = node
      @val = val
    end

    attr_reader :node, :val
  end

  class MethodEntry
    def initialize(cpath, singleton, mid)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
    end

    attr_reader :cpath, :singleton, :mid
  end

  class MethodDecl < MethodEntry
    def initialize(cpath, singleton, mid, rbs_member)
      super(cpath, singleton, mid)
      @rbs_member = rbs_member
      @builtin = nil
    end

    attr_reader :rbs_member, :builtin

    def resolve_overloads(genv, recv_ty, a_args, block, ret)
      all_edges = Set[]
      map = {
        __self: (@singleton ? Type::Module : Type::Instance).new(@cpath),
      }
      if recv_ty.is_a?(Type::Array)
        map[:Elem] = recv_ty.elem
      end
      @rbs_member.overloads.each do |overload|
        edges = Set[]
        func = overload.method_type.type
        # func.optional_keywords
        # func.optional_positionals
        # func.required_keywords
        # func.rest_keywords
        # func.rest_positionals
        # func.trailing_positionals
        # TODO: only one argument!
        f_args = func.required_positionals.map do |f_arg|
          Signatures.type(genv, f_arg.type, map)
        end
        # TODO: correct block match
        if a_args.size == f_args.size
          match = a_args.zip(f_args).all? do |a_arg, f_arg|
            a_arg.types.any? do |a_ty,|
              f_arg.any? do |f_ty|
                # TODO: type consistency
                a_ty.match?(genv, f_ty)
              end
            end
          end
          rbs_blk = overload.method_type.block
          if block
            blk = overload.method_type.block
            if blk
              blk_func = rbs_blk.type
              # blk_func.optional_keywords
              # ..
              block.types.each do |ty, _source|
                case ty
                when Type::Proc
                  blk_a_args = blk_func.required_positionals.map do |blk_a_arg|
                    Signatures.type(genv, blk_a_arg.type, map)
                  end
                  blk_f_args = ty.block.f_args
                  if blk_a_args.size == blk_f_args.size
                    blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                      blk_a_arg.each do |a_ty|
                        edges << [Source.new(a_ty), blk_f_arg]
                      end
                    end
                  else
                    match = false
                  end
                else
                  "???"
                end
              end
            else
              match = false
            end
          else
            if rbs_blk
              match = false
            end
          end
          if match
            Signatures.type(genv, func.return_type, map).each do |ret_ty|
              edges << [Source.new(ret_ty), ret]
            end
            edges.each do |src, dst|
              all_edges << [src, dst]
            end
          end
        end
      end
      all_edges
    end

    def set_builtin(&blk)
      @builtin = blk
    end

    def inspect
      "#<MethodDecl ...>"
    end
  end

  class MethodDef < MethodEntry
    def initialize(cpath, singleton, mid, node, f_args, block, ret)
      super(cpath, singleton, mid)
      @node = node
      raise unless f_args
      @f_args = f_args
      @block = block
      @ret = ret
    end

    attr_reader :cpath, :singleton, :mid, :node, :f_args, :block, :ret

    def show
      block_show = []
      # just for debug
      if @block
        @block.types.each_key do |ty|
          case ty
          when Type::Proc
            block_show << "{ (#{ ty.block.f_args.map {|arg| arg.show }.join(", ") }) -> #{ ty.block.ret.show } }"
          else
            puts "???"
          end
        end
      end
      s = "(#{ @f_args.map {|arg| arg.show }.join(", ") })"
      s << " (#{ block_show.sort.join(" | ") })" unless block_show.empty?
      s << " -> #{ @ret.show }"
    end
  end

  class Block
    def initialize(node, f_args, ret)
      @node = node
      @f_args = f_args
      @ret = ret
    end

    attr_reader :node, :f_args, :ret
  end

  class IVarDef
    def initialize(cpath, singleton, name, node, val)
      @cpath = cpath
      @singleton = singleton
      @name = name
      @node = node
      @val = val
    end

    attr_reader :cpath, :singleton, :name
    attr_reader :node, :val

    def show
      "<TODO IVarDef>"
    end
  end

  class GlobalEnv
    def initialize
      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleDirectory.new
      @toplevel.child_modules[:Object] = @toplevel

      loader = RBS::EnvironmentLoader.new
      @rbs_env = RBS::Environment.from_loader(loader).resolve_type_names
      @rbs_builder = RBS::DefinitionBuilder.new(env: rbs_env)

      @creadsites_by_name = {}
      @callsites_by_name = {}
      @ivreadsites_by_name = {}
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

    # classes and modules

    def resolve_cpath(cpath)
      dir = @toplevel
      cpath.each do |cname|
        dir = dir.child_modules[cname] ||= ModuleDirectory.new
      end
      dir
    end

    def add_module(cpath, mod_def, superclass_cpath = nil)
      dir = resolve_cpath(cpath)
      dir.module_defs << mod_def
      if superclass_cpath
        if dir.superclass_cpath
          # error
        else
          dir.superclass_cpath = superclass_cpath
        end
      end
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

    # consts

    def get_const_entity(ce)
      dir = resolve_cpath(ce.cpath)
      dir.consts[ce.cname] ||= Entity.new
    end

    def add_const_decl(cdecl)
      e = get_const_entity(cdecl)
      e.decls << cdecl
    end

    def add_const_def(cdef)
      e = get_const_entity(cdef)
      e.defs << cdef

      run_creadsite(cdef.cname)
    end

    def remove_const_def(cdef)
      e = get_const_entity(cdef)
      e.defs.delete(cdef)

      run_creadsite(cdef.cname)
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

    def add_creadsite(creadsite)
      (@creadsites_by_name[creadsite.cname] ||= Set[]) << creadsite
      add_run(creadsite)
    end

    def remove_creadsite(creadsite)
      @creadsites_by_name[creadsite.cname].delete(creadsite)
    end

    def run_creadsite(cname)
      creadsites = @creadsites_by_name[cname]
      if creadsites
        creadsites.each do |creadsite|
          add_run(creadsite)
        end
      end
    end

    # methods

    def get_method_entity(me)
      dir = resolve_cpath(me.cpath)
      dir.methods(me.singleton)[me.mid] ||= Entity.new
    end

    def add_method_decl(mdecl)
      e = get_method_entity(mdecl)
      e.decls << mdecl
    end

    # TODO: remove_method_decl

    def add_method_def(mdef)
      e = get_method_entity(mdef)
      e.defs << mdef

      run_callsite(mdef.mid)
    end

    def remove_method_def(mdef)
      e = get_method_entity(mdef)
      e.defs.delete(mdef)

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

    def add_callsite(callsite)
      (@callsites_by_name[callsite.mid] ||= Set[]) << callsite
      add_run(callsite)
    end

    def remove_callsite(callsite)
      @callsites_by_name[callsite.mid].delete(callsite)
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

    # instance variables

    def get_ivar_entity(ive)
      dir = resolve_cpath(ive.cpath)
      dir.ivars(ive.singleton)[ive.name] ||= Entity.new
    end

    def add_ivar_decl(ivdecl)
      e = get_ivar_entity(ivdecl)
      e.decls << ivdecl
    end

    def add_ivar_def(ivdef)
      e = get_ivar_entity(ivdef)
      e.defs << ivdef

      run_ivreadsite(ivdef.name)
    end

    def remove_ivar_def(ivdef)
      e = get_ivar_entity(ivdef)
      e.defs.delete(ivdef)

      run_ivreadsite(ivdef.name)
    end

    def resolve_ivar(cpath, singleton, name)
      while cpath
        dir = resolve_cpath(cpath)
        e = dir.ivars(singleton)[name]
        if e
          return e.decls unless e.decls.empty?
          return e.defs unless e.defs.empty?
        end
        cpath = dir.superclass_cpath
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

    def add_ivreadsite(ivreadsite)
      (@ivreadsites_by_name[ivreadsite.name] ||= Set[]) << ivreadsite
      add_run(ivreadsite)
    end

    def remove_ivreadsite(ivreadsite)
      @ivreadsites_by_name[ivreadsite.name].delete(ivreadsite)
    end

    def run_ivreadsite(name)
      ivreadsites = @ivreadsites_by_name[name]
      if ivreadsites
        ivreadsites.each do |ivreadsite|
          add_run(ivreadsite)
        end
      end
    end

    def subclass?(cpath1, cpath2)
      while cpath1
        return true if cpath1 == cpath2
        break if cpath1 == [:BasicObject]
        dir = resolve_cpath(cpath1)
        cpath1 = dir.superclass_cpath
      end
      return false
    end
  end
end