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

  class ConstRead
    def initialize(node, cname)
      @node = node
      @cname = cname
      @const_reads = Set[]
      @cpath = nil
      @cdef = nil
    end

    attr_reader :cref, :cname, :cpath, :cdef, :const_reads

    def propagate(genv)
      @const_reads.dup.each do |const_read|
        case const_read
        when ScopedConstRead
          const_read.on_cbase_updated(genv)
        when Array
          genv.resolve_cpath(const_read).on_superclass_updated(genv)
        else
          raise const_read.inspect
        end
      end
    end

    def resolve(genv, cref)
      first = true
      while cref
        scope = cref.cpath
        while true
          m = genv.resolve_cpath(scope)
          mm = genv.resolve_cpath(scope + [@cname])
          if !mm.module_decls.empty? || !mm.module_defs.empty?
            cpath = scope + [@cname]
          end
          if m.child_consts[@cname] && (!m.child_consts[@cname].decls.empty? || !m.child_consts[@cname].defs.empty?) # TODO: const_decls
            cdef = m.child_consts[@cname]
          end
          return [cpath, cdef] if cpath || cdef
          break unless first
          break unless m.superclass_cpath
          break if scope == [:BasicObject]
          scope = m.superclass_cpath
        end
        first = false
        cref = cref.outer
      end
      return nil
    end
  end

  class BaseConstRead < ConstRead
    def initialize(node, cname, cref)
      super(node, cname)
      @cref = cref
    end

    attr_reader :cref

    def on_scope_updated(genv)
      cpath, cdef = resolve(genv, @cref)
      if cpath != @cpath || cdef != @cdef
        @cpath = cpath
        @cdef = cdef
        propagate(genv)
      end
    end
  end

  class ScopedConstRead < ConstRead
    def initialize(node, cname, cbase)
      super(node, cname)
      @cbase = cbase
      @cbase.const_reads << self if @cbase
      @cbase_cpath = nil
    end

    attr_reader :cbase

    def on_cbase_updated(genv)
      if @cbase && @cbase.cpath
        cpath, cdef = resolve(genv, CRef.new(@cbase.cpath, false, nil))
        if cpath != @cpath || cdef != @cdef
          genv.resolve_cpath(@cbase_cpath).const_reads.delete(self) if @cbase_cpath
          @cpath = cpath
          @cdef = cdef
          @cbase_cpath = @cbase.cpath
          genv.resolve_cpath(@cbase_cpath).const_reads << self if @cbase_cpath
          propagate(genv)
        end
      end
    end
  end

  class Entity
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

  class GVarEntry
    def initialize(name)
      @name = name
    end

    attr_reader :name
  end

  class GVarDecl < GVarEntry
    def initialize(name, type)
      super(name)
      @type = type
    end

    attr_reader :type
  end

  class GVarDef < GVarEntry
    def initialize(name, node, val)
      super(name)
      @node = node
      @val = val
    end

    attr_reader :node, :val

    def show
      "<TODO GVarDef>"
    end
  end

  class IVarDef
    def initialize(cpath, singleton, name, node, val)
      @cpath = cpath
      @singleton = singleton
      @name = name
      @node = node
      @val = val
    end

    attr_reader :cpath, :singleton, :name, :node, :val

    def show
      "<TODO IVarDef>"
    end
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
      @gvreadsites_by_name = {}
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
      # TODO: gvars and others?
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
      add_const_decl(cpath, mod_decl, Source.new(Type::Module.new(cpath)))

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

    class ConstDef
      def initialize(cpath)
        @cpath = cpath
        @decls = Set[]
        @defs = Set[]
        @vtx = nil
      end

      attr_reader :cpath, :decls, :defs, :vtx

      def add_decl(decl, vtx)
        @decls << decl
        @vtx = vtx
      end

      def remove_decl(decl)
        @decls.delete(decl)
      end

      def add_def(node)
        @defs << node
        @vtx = Vertex.new("const-def", node) unless @vtx
        self
      end

      def remove_def(node)
        @defs.delete(node)
      end
    end

    def resolve_const(cpath)
      dir = resolve_cpath(cpath[0..-2])
      dir.child_consts[cpath[-1]] ||= ConstDef.new(cpath)
    end

    def add_const_decl(cpath, decl, vtx)
      cdef = resolve_const(cpath)
      cdef.add_decl(decl, vtx)
    end

    # TODO: remove_const_decl

    def add_const_def(cpath, node)
      resolve_const(cpath).add_def(node)
    end

    def remove_const_def(cpath, node)
      resolve_const(cpath).remove_def(node)
    end

    def add_const_read(const)
      cref = const.cref
      while cref
        resolve_cpath(cref.cpath).const_reads << const
        cref = cref.outer
      end
      @define_queue << const
    end

    def remove_const_read(const)
      cref = const.cref
      while cref
        resolve_cpath(cref.cpath).const_reads.delete(const)
        cref = cref.outer
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

    def get_gvar_entity(gve)
      @gvars[gve.name] ||= Entity.new
    end

    def add_gvar_decl(gvdecl)
      e = get_gvar_entity(gvdecl)
      e.decls << gvdecl
    end

    def add_gvar_def(gvdef)
      e = get_gvar_entity(gvdef)
      e.defs << gvdef

      run_gvreadsite(gvdef.name)
    end

    def remove_gvar_def(gvdef)
      e = get_gvar_entity(gvdef)
      e.defs.delete(gvdef)

      run_gvreadsite(gvdef.name)
    end

    def resolve_gvar(name)
      e = @gvars[name]
      if e
        return e.decls unless e.decls.empty?
        return e.defs unless e.defs.empty?
      end
      return nil
    end

    def add_gvreadsite(gvreadsite)
      (@gvreadsites_by_name[gvreadsite.name] ||= Set[]) << gvreadsite
      add_run(gvreadsite)
    end

    def remove_gvreadsite(gvreadsite)
      @gvreadsites_by_name[gvreadsite.name].delete(gvreadsite)
    end

    def run_gvreadsite(name)
      gvreadsites = @gvreadsites_by_name[name]
      if gvreadsites
        gvreadsites.each do |gvreadsite|
          add_run(gvreadsite)
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