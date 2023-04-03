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

    def add_depended_method_entities(dir, singleton, mid)
      @new_depended_method_entities << [dir, singleton, mid]
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
        callsite.node.remove_site(genv, key)
      end
      @new_callsites.each do |key, callsite|
        callsite.node.add_site(key, callsite)
      end
      @callsites, @new_callsites = @new_callsites, @callsites
      @new_callsites.clear

      @diagnostics, @new_diagnostics = @new_diagnostics, @diagnostics
      @new_diagnostics.clear

      @depended_method_entities.each do |dir, singleton, mid|
        dir.remove_depended_method_entity(singleton, mid, @target)
      end
      @new_depended_method_entities.each do |dir, singleton, mid|
        dir.add_depended_method_entity(singleton, mid, @target)
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

  class MethodDefSite < Site
    def initialize(node, genv, cpath, singleton, mid, f_args, block, ret)
      @node = node
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      raise unless f_args
      @f_args = f_args
      @block = block
      @ret = ret
      genv.resolve_method(@cpath, @singleton, @mid).add_def(self)
      genv.resolve_cpath(@cpath).add_run_all_callsites(genv, @singleton, @mid)
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :f_args, :block, :ret

    def destroy(genv)
      genv.resolve_method(@cpath, @singleton, @mid).remove_def(self)
      genv.resolve_cpath(@cpath).add_run_all_callsites(genv, @singleton, @mid)
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
        changes.add_diagnostic(
          TypeProf::Diagnostic.new(call_node.mid_code_range || call_node, "wrong number of arguments (#{ a_args.size } for #{ @f_args.size })")
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
          cr = @node.mid_code_range || @node
          changes.add_diagnostic(
            TypeProf::Diagnostic.new(cr, "undefined method: #{ recv_ty.show }##{ @mid }")
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
          cpath = base_ty.cpath
          singleton = base_ty.is_a?(Type::Module)
          dir = genv.resolve_cpath(cpath)
          dir.traverse_subclasses do |subclass_dir|
            next if dir == subclass_dir
            changes.add_depended_method_entities(subclass_dir, singleton, @mid)
            me = subclass_dir.get_method(singleton, @mid)
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
          case ty.base_types(genv).first.cpath # XXX first?
          when [:Set]
            param_map[:A] = ty.get_elem
          when [:Array], [:Enumerator]
            param_map[:Elem] = ty.get_elem
          end
        when Type::Hash
          param_map[:K] = ty.get_key
          param_map[:V] = ty.get_value
        end
        mid = @mid
        ty.base_types(genv).each do |base_ty|
          cpath = base_ty.cpath
          singleton = base_ty.is_a?(Type::Module)
          found = false
          dir = genv.resolve_cpath(cpath)
          while dir
            changes.add_depended_method_entities(dir, singleton, mid) if changes

            me = dir.get_method(singleton, mid)
            if !me.aliases.empty?
              mid = me.aliases.values.first
              redo
            end
            if me && me.exist?
              found = true
              break
            end

            unless singleton # TODO
              dir.included_modules.each_value do |mod_dir|
                changes.add_depended_method_entities(mod_dir, singleton, mid) if changes
                me = mod_dir.get_method(singleton, mid)
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

            dir, singleton = genv.get_superclass(dir, singleton)
          end
          if found
            yield ty, @mid, me, param_map
          else
            yield ty, @mid, nil, param_map
          end
        end
      end
    end

    def diagnostics(genv)
      @changes.diagnostics[0, 3].each do |diag|
        yield diag
      end
      if @changes.diagnostics.size >= 4
        TypeProf::Diagnostic.new(@node.mid_code_range || @node, "(and #{ @changes.diagnostics.size - 3 } errors omitted)")
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
      dir = genv.resolve_cpath(@cpath)
      singleton = @singleton
      cur_ive = dir.get_ivar(singleton, @name)
      target_vtx = nil
      while dir
        ive = dir.get_ivar(singleton, @name)
        if ive.exist?
          target_vtx = ive.vtx
        end
        dir, singleton = genv.get_superclass(dir, singleton)
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
            edges << [ty.get_elem(i), lhs]
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