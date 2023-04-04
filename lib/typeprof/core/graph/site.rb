module TypeProf::Core
  class Changes
    def initialize(target)
      @target = target
      @edges = Set[]
      @new_edges = Set[]
      @callsites = {}
      @new_callsites = {}
      @diagnostics = []
      @new_diagnostics = []
      @depended_method_entities = []
      @new_depended_method_entities = []
    end

    attr_reader :diagnostics

    def add_edge(src, dst)
      @new_edges << [src, dst]
    end

    def add_callsite(key, callsite)
      @new_callsites[key] = callsite
    end

    def add_diagnostic(diag)
      @new_diagnostics << diag
    end

    def add_depended_method_entities(me)
      @new_depended_method_entities << me
    end

    def reinstall(genv)
      @new_edges.each do |src, dst|
        src.add_edge(genv, dst) unless @edges.include?([src, dst])
      end
      @edges.each do |src, dst|
        src.remove_edge(genv, dst) unless @new_edges.include?([src, dst])
      end
      @edges, @new_edges = @new_edges, @edges
      @new_edges.clear

      @callsites.each do |key, callsite|
        callsite.destroy(genv)
        callsite.node.remove_site(key, callsite)
      end
      @new_callsites.each do |key, callsite|
        callsite.node.add_site(key, callsite)
      end
      @callsites, @new_callsites = @new_callsites, @callsites
      @new_callsites.clear

      @diagnostics, @new_diagnostics = @new_diagnostics, @diagnostics
      @new_diagnostics.clear

      @depended_method_entities.each do |me|
        me.callsites.delete(@target)
      end
      @new_depended_method_entities.each do |me|
        me.callsites << @target
      end

      @depended_method_entities, @new_depended_method_entities = @new_depended_method_entities, @depended_method_entities
      @depended_method_entities.clear
    end
  end

  $site_counts = Hash.new(0)
  class Site
    def initialize(node)
      @node = node
      @changes = Changes.new(self)
      @destroyed = false
      $site_counts[Site] += 1
      $site_counts[self.class] += 1
    end

    attr_reader :node, :destroyed

    def destroy(genv)
      $site_counts[self.class] -= 1
      $site_counts[Site] -= 1
      @destroyed = true
      @changes.reinstall(genv) # rollback all changes
    end

    def reuse(node)
      @node = node
    end

    def on_type_added(genv, src_tyvar, added_types)
      genv.add_run(self)
    end

    def on_type_removed(genv, src_tyvar, removed_types)
      genv.add_run(self)
    end

    def run(genv)
      return if @destroyed
      run0(genv, @changes)

      @changes.reinstall(genv)
    end

    def diagnostics(genv, &blk)
      raise self.to_s if !@changes
      @changes.diagnostics.each(&blk)
    end

    #@@new_id = 0

    def to_s
      "#{ self.class.to_s.split("::").last[0] }#{ @id ||= $new_id += 1 }"
    end

    alias inspect to_s
  end

  class ConstReadSite < Site
    def initialize(node, genv, const_read)
      super(node)
      @const_read = const_read
      const_read.followers << self
      @ret = Vertex.new("cname", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv, changes)
      cdef = @const_read.cdef
      changes.add_edge(cdef.vtx, @ret) if cdef
    end

    def long_inspect
      "#{ to_s } (cname:#{ @cname } @ #{ @node.code_range })"
    end
  end

  class MethodDeclSite < Site
    def initialize(node, genv, cpath, singleton, mid, rbs_method_types)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      @rbs_method_types = rbs_method_types
      @ret = Source.new

      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.add_decl(self)
      me.add_run_all_callsites(genv)
      me.add_run_all_mdefs(genv)
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :rbs_method_types, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.remove_decl(self)
      me.add_run_all_callsites(genv)
    end

    def resolve_overloads(changes, genv, node, param_map, a_args, block, ret)
      @rbs_method_types.each do |method_type|
        rbs_func = method_type.type
        # rbs_func.optional_keywords
        # rbs_func.optional_positionals
        # rbs_func.required_keywords
        # rbs_func.rest_keywords
        # rbs_func.rest_positionals
        # rbs_func.trailing_positionals
        param_map0 = param_map.dup
        method_type.type_params.map do |param|
          param_map0[param.name] = Vertex.new("type-param:#{ param.name }", node)
        end
        f_args = rbs_func.required_positionals.map do |f_arg|
          Signatures.type_to_vtx(genv, node, f_arg.type, param_map0)
        end
        next if a_args.size != f_args.size
        next if !f_args.all? # skip interface type
        next if a_args.zip(f_args).any? {|a_arg, f_arg| !a_arg.match?(genv, f_arg) }
        rbs_blk = method_type.block
        next if !!rbs_blk != !!block
        if rbs_blk && block
          rbs_blk_func = rbs_blk.type
          # rbs_blk_func.optional_keywords, ...
          block.types.each do |ty, _source|
            case ty
            when Type::Proc
              blk_a_args = rbs_blk_func.required_positionals.map do |blk_a_arg|
                Signatures.type_to_vtx(genv, node, blk_a_arg.type, param_map0)
              end
              blk_f_args = ty.block.f_args
              if blk_a_args.size == blk_f_args.size # TODO: pass arguments for block
                blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                  changes.add_edge(blk_a_arg, blk_f_arg)
                end
                blk_f_ret = Signatures.type_to_vtx(genv, node, rbs_blk_func.return_type, param_map0) # TODO: Sink instead of Source
                changes.add_edge(ty.block.ret, blk_f_ret)
              end
            end
          end
        end
        ret_vtx = Signatures.type_to_vtx(genv, node, rbs_func.return_type, param_map0)
        changes.add_edge(ret_vtx, ret)
      end
    end
  end

  class MethodDefSite < Site
    def initialize(node, genv, cpath, singleton, mid, f_args, block, ret)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      raise unless f_args
      @f_args = f_args
      @block = block
      @ret = ret
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.add_def(self)
      if me.decls.empty?
        me.add_run_all_callsites(genv)
      else
        genv.add_run(self)
      end
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :f_args, :block, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.remove_def(self)
      if me.decls.empty?
        me.add_run_all_callsites(genv)
      else
        genv.add_run(self)
      end
    end

    def run0(genv, changes)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      return if me.decls.empty?

      # TODO: support "| ..."
      decl = me.decls.to_a.first
      # TODO: support overload?
      method_type = decl.rbs_method_types.first
      _block = method_type.block
      rbs_func = method_type.type

      param_map0 = {}
      method_type.type_params.map do |param|
        param_map0[param.name] = Vertex.new("type-param:#{ param.name }", node)
      end
      a_args = rbs_func.required_positionals.map do |a_arg|
        Signatures.type_to_vtx(genv, node, a_arg.type, param_map0)
      end

      if a_args.size == @f_args.size
        a_args.zip(@f_args) do |a_arg, f_arg|
          changes.add_edge(a_arg, f_arg)
        end
      end

      # TODO: block
      # TODO: return value check
    end

    def call(changes, genv, call_node, a_args, block, ret)
      if a_args.size == @f_args.size
        if block && @block
          changes.add_edge(block, @block)
        end
        # check arity
        a_args.zip(@f_args) do |a_arg, f_arg|
          break unless f_arg
          changes.add_edge(a_arg, f_arg)
        end
        changes.add_edge(@ret, ret)
      else
        meth = call_node.mid_code_range ? :mid_code_range : :code_range
        changes.add_diagnostic(
          TypeProf::Diagnostic.new(call_node, meth, "wrong number of arguments (#{ a_args.size } for #{ @f_args.size })")
        )
      end
    end

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

  class CallSite < Site
    def initialize(node, genv, recv, mid, a_args, block, subclasses)
      raise mid.to_s unless mid
      super(node)
      @recv = recv.new_vertex(genv, "recv:#{ mid }", node)
      @recv.add_edge(genv, self)
      @mid = mid
      @a_args = a_args.map do |a_arg|
        a_arg = a_arg.new_vertex(genv, "arg:#{ mid }", node)
        a_arg.add_edge(genv, self)
        a_arg
      end
      if block
        @block = block.new_vertex(genv, "block:#{ mid }", node)
        @block.add_edge(genv, self) # needed?
      end
      @ret = Vertex.new("ret:#{ mid }", node)
      @subclasses = subclasses
    end

    attr_reader :recv, :mid, :a_args, :block, :ret

    def run0(genv, changes)
      edges = Set[]
      resolve(genv, changes) do |recv_ty, mid, me, param_map|
        if !me
          # TODO: undefined method error
          meth = @node.mid_code_range ? :mid_code_range : :code_range
          changes.add_diagnostic(
            TypeProf::Diagnostic.new(@node, meth, "undefined method: #{ recv_ty.show }##{ @mid }")
          )
        elsif me.builtin
          # TODO: block? diagnostics?
          me.builtin[changes, @node, recv_ty, @a_args, @ret]
        elsif !me.decls.empty?
          # TODO: support "| ..."
          me.decls.each do |mdecl|
            # TODO: union type is ok?
            # TODO: add_depended_method_entities for types used to resolve overloads
            mdecl.resolve_overloads(changes, genv, @node, param_map, @a_args, @block, @ret)
          end
        elsif !me.defs.empty?
          me.defs.each do |mdef|
            mdef.call(changes, genv, @node, @a_args, @block, @ret)
          end
        else
          pp me
          raise
        end
      end
      if @subclasses
        resolve_subclasses(genv, changes) do |recv_ty, me|
          if !me.defs.empty?
            me.defs.each do |mdef|
              mdef.call(changes, genv, @node, @a_args, @block, @ret)
            end
          end
        end
      end
      edges.each do |src, dst|
        changes.add_edge(src, dst)
      end
    end

    def resolve_subclasses(genv, changes)
      # TODO: This does not follow new subclasses
      @recv.types.each do |ty, _source|
        next if ty == Type::Bot.new
        ty.base_types(genv).each do |base_ty|
          singleton = base_ty.is_a?(Type::Module)
          mod = base_ty.mod
          mod.each_descendant do |desc_mod|
            next if mod == desc_mod
            me = desc_mod.get_method(singleton, @mid)
            changes.add_depended_method_entities(me)
            if me && me.exist?
              yield ty, me
            end
          end
        end
      end
    end

    def resolve(genv, changes = nil)
      @recv.types.each do |ty, _source|
        next if ty == Type::Bot.new
        param_map = { __self: Source.new(ty) }
        case ty
        when Type::Array
          case ty.base_types(genv).first.mod.cpath # XXX first?
          when [:Set]
            param_map[:A] = ty.get_elem(genv)
          when [:Array], [:Enumerator]
            param_map[:Elem] = ty.get_elem(genv)
          end
        when Type::Hash
          param_map[:K] = ty.get_key
          param_map[:V] = ty.get_value
        end
        mid = @mid
        ty.base_types(genv).each do |base_ty|
          mod = base_ty.mod
          singleton = base_ty.is_a?(Type::Module)
          found = false
          while mod
            me = mod.get_method(singleton, mid)
            changes.add_depended_method_entities(me) if changes
            if !me.aliases.empty?
              mid = me.aliases.values.first
              redo
            end
            if me && me.exist?
              found = true
              break
            end

            unless singleton # TODO
              mod.included_modules.each_value do |inc_mod|
                me = inc_mod.get_method(singleton, mid)
                changes.add_depended_method_entities(me) if changes
                if !me.aliases.empty?
                  mid = me.aliases.values.first
                  redo
                end
                # TODO: module alias??
                if me && me.exist?
                  found = true
                  break
                end
              end
              break if found
            end

            # TODO: included modules
            # TODO: update type params

            mod, singleton = genv.get_superclass(mod, singleton)
          end
          if found
            yield ty, @mid, me, param_map
          else
            yield ty, @mid, nil, param_map
          end
        end
      end
    end

    def long_inspect
      "#{ to_s } (mid:#{ @mid } @ #{ @node.code_range })"
    end
  end

  class GVarReadSite < Site
    def initialize(node, genv, name)
      super(node)
      @vtx = genv.resolve_gvar(name).vtx
      @ret = Vertex.new("gvar", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv, changes)
      changes.add_edge(@vtx, @ret)
    end

    def long_inspect
      "TODO"
    end
  end

  class IVarReadSite < Site
    def initialize(node, genv, cpath, singleton, name)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @name = name
      genv.resolve_cpath(cpath).ivar_reads << self
      @proxy = Vertex.new("ivar", node)
      @ret = Vertex.new("ivar", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def destroy(genv)
      genv.resolve_cpath(@cpath).ivar_reads.delete(self)
      super
    end

    def run0(genv, changes)
      mod = genv.resolve_cpath(@cpath)
      singleton = @singleton
      cur_ive = mod.get_ivar(singleton, @name)
      target_vtx = nil
      while mod
        ive = mod.get_ivar(singleton, @name)
        if ive.exist?
          target_vtx = ive.vtx
        end
        mod, singleton = genv.get_superclass(mod, singleton)
      end
      edges = []
      if target_vtx
        if target_vtx != cur_ive.vtx
          edges << [cur_ive.vtx, @proxy] << [@proxy, target_vtx]
        end
        edges << [target_vtx, @ret]
      else
        # TODO: error?
      end
      edges.each do |src, dst|
        changes.add_edge(src, dst)
      end
    end

    def long_inspect
      "IVarTODO"
    end
  end

  class MAsgnSite < Site
    def initialize(node, genv, rhs, lhss)
      super(node)
      @rhs = rhs
      @lhss = lhss
      @rhs.add_edge(genv, self)
    end

    attr_reader :node, :rhs, :lhss

    def ret = @rhs

    def run0(genv, changes)
      edges = []
      @rhs.types.each do |ty, _source|
        case ty
        when Type::Array
          @lhss.each_with_index do |lhs, i|
            edges << [ty.get_elem(genv, i), lhs]
          end
        else
          edges << [Source.new(ty), @lhss[0]]
        end
      end
      edges.each do |src, dst|
        changes.add_edge(src, dst)
      end
    end

    def long_inspect
      "#{ to_s } (masgn)"
    end
  end
end