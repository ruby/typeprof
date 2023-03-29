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

    def resolve_overloads(genv, node, recv_ty, a_args, block, ret)
      all_edges = Set[]
      self_ty = (@singleton ? Type::Module : Type::Instance).new(@cpath)
      param_map = {
        __self: Source.new(self_ty),
      }
      case recv_ty
      when Type::Array
        case recv_ty.base_types(genv).first.cpath
        when [:Set]
          param_map[:A] = recv_ty.get_elem
        when [:Array], [:Enumerator]
          param_map[:Elem] = recv_ty.get_elem
        end
      when Type::Hash
        param_map[:K] = recv_ty.get_key
        param_map[:V] = recv_ty.get_value
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
        param_map0 = param_map.dup
        overload.method_type.type_params.map do |param|
          param_map0[param.name] = Vertex.new("type-param:#{ param.name }", node)
        end
        #puts; p [@cpath, @singleton, @mid]
        f_args = func.required_positionals.map do |f_arg|
          Signatures.type_to_vtx(genv, node, f_arg.type, param_map0)
        end
        # TODO: correct block match
        if a_args.size == f_args.size && f_args.all? # skip interface type
          match = a_args.zip(f_args).all? do |a_arg, f_arg|
            a_arg.match?(genv, f_arg)
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
                    Signatures.type_to_vtx(genv, node, blk_a_arg.type, param_map0)
                  end
                  blk_f_args = ty.block.f_args
                  if blk_a_args.size == blk_f_args.size
                    blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                      edges << [blk_a_arg, blk_f_arg]
                    end
                    blk_f_ret = Signatures.type_to_vtx(genv, node, blk_func.return_type, param_map0)
                    ty.block.ret.add_edge(genv, blk_f_ret)
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
            ret_vtx = Signatures.type_to_vtx(genv, node, func.return_type, param_map0)
            edges << [ret_vtx, ret]
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
      s = []
      s << "(#{ @f_args.map {|arg| Type.strip_parens(arg.show) }.join(", ") })" unless @f_args.empty?
      s << "#{ block_show.sort.join(" | ") }" unless block_show.empty?
      s << "-> #{ @ret.show }"
      s.join(" ")
    end
  end

  class MethodAlias < MethodEntry
    def initialize(cpath, singleton, new_mid, old_mid, source)
      super(cpath, singleton, new_mid)
      @old_mid = old_mid
      @source = source
    end

    attr_reader :old_mid, :source
  end

  class Block
    def initialize(node, f_args, ret)
      @node = node
      @f_args = f_args
      @ret = ret
    end

    attr_reader :node, :f_args, :ret
  end

  class GlobalEnv
    def initialize(rbs_builder)
      @define_queue = []

      @run_queue = []
      @run_queue_set = Set[]

      @toplevel = ModuleDirectory.new([])
      @toplevel.child_modules[:Object] = @toplevel

      @gvars = {}

      @rbs_builder = rbs_builder

      @callsites_by_name = {}
      @ivreadsites_by_name = {}
    end

    attr_reader :rbs_builder

    def define_all
      @define_queue.uniq.each do |v|
        case v
        when Array # cpath
          resolve_cpath(v).on_child_modules_updated(self)
        when BaseConstRead
          v.on_scope_updated(self)
        else
          raise
        end
      end
      @define_queue.clear
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
        dir = dir.child_modules[cname] ||= ModuleDirectory.new(dir.cpath + [cname])
      end
      dir
    end

    def add_module_decl(cpath, mod_decl)
      dir = resolve_cpath(cpath)
      dir.module_decls << mod_decl

      if mod_decl.is_a?(RBS::AST::Declarations::Class)
        superclass = mod_decl.super_class
        if superclass
          cpath = superclass.name.namespace.path + [superclass.name.name]
        else
          cpath = []
        end
        dir.set_superclass_cpath(cpath)
      end

      dir
    end

    def add_module_def(cpath, mod_def)
      dir = resolve_cpath(cpath)
      if dir.module_defs.empty?
        @define_queue << cpath[0..-2]
      end
      dir.module_defs << mod_def
      dir
    end

    def remove_module_def(cpath, mod_def)
      dir = resolve_cpath(cpath)
      dir.module_defs.delete(mod_def)
      if dir.module_defs.empty?
        @define_queue << cpath[0..-2]
      end
    end

    def set_superclass(cpath, superclass_cpath)
      dir = resolve_cpath(cpath)
      dir.superclass_cpath = superclass_cpath
    end

    # module inclusion

    def add_module_include(cpath, mod_cpath)
      dir = resolve_cpath(cpath)
      dir.include_module_cpaths << mod_cpath
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
      @define_queue << const_read
    end

    def remove_const_read(const_read)
      cref = const_read.cref
      while cref
        resolve_cpath(cref.cpath).const_reads.delete(const_read)
        cref = cref.outer
      end
    end

    # methods

    def get_method_entity(me)
      dir = resolve_cpath(me.cpath)
      dir.methods(me.singleton)[me.mid] ||= OldEntity.new
    end

    def add_method_decl(mdecl)
      e = get_method_entity(mdecl)
      e.decls << mdecl
    end

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

    def add_method_alias(malias)
      e = get_method_entity(malias)
      e.aliases << malias

      run_callsite(malias.mid)
    end

    def remove_method_alias(malias)
      e = get_method_entity(malias)
      e.aliases.delete(malias)

      run_callsite(malias.mid)
    end

    def resolve_method(cpath, singleton, mid)
      enumerate_methods(cpath, singleton) do |_cpath, _singleton, methods|
        e = methods[mid]
        if e
          return e.decls unless e.decls.empty?
          return e.defs unless e.defs.empty?
          unless e.aliases.empty?
            # TODO
            mid = e.aliases.to_a.first.old_mid
            redo
          end
        end
      end
    end

    def enumerate_methods(cpath, singleton)
      while true
        dir = resolve_cpath(cpath)
        yield cpath, singleton, dir.methods(singleton)
        unless singleton # TODO
          dir.include_module_cpaths.each do |mod_cpath|
            mod_dir = resolve_cpath(mod_cpath)
            yield mod_cpath, false, mod_dir.methods(false)
          end
        end
        if cpath == [:BasicObject]
          if singleton
            singleton = false
            cpath = [:Class]
          else
            break
          end
        else
          cpath = dir.superclass_cpath
          unless cpath
            cpath = [:Module]
            singleton = false
          end
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

    # global variables

    def resolve_gvar(name)
      @gvars[name] ||= Entity.new
    end

    # instance variables

    def resolve_ivar(cpath, singleton, name)
      # TODO: include はあとで考える
      dir = resolve_cpath(cpath)
      dir.ivars[singleton][name] ||= Entity.new
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