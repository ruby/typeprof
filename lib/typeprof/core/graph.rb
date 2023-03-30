module TypeProf::Core
  Fiber[:show_rec] = Set[]

  class BasicVertex
    def initialize(types)
      @types = types
    end

    attr_reader :types

    def show
      if Fiber[:show_rec].include?(self)
        "untyped"
      else
        begin
          Fiber[:show_rec] << self
          types = []
          bot = @types.include?(Type::Bot.new)
          optional = @types.include?(Type.nil)
          bool = @types.include?(Type.true) && @types.include?(Type.false)
          types << "bool" if bool
          @types.each do |ty, _source|
            next if ty == Type.nil
            next if bool && (ty == Type.true || ty == Type.false)
            next if ty == Type::Bot.new
            types << ty.show
          end
          types = types.uniq.sort
          ret = case types.size
          when 0
            optional ? "nil" : bot ? "bot" : "untyped"
          when 1
            types.first + (optional ? "?" : "")
          else
            "(#{ types.join(" | ") })" + (optional ? "?" : "")
          end
        #ensure
          Fiber[:show_rec].delete(self)
          ret
        end
      end
    end
  end

  class Source < BasicVertex
    def initialize(*tys)
      types = {}
      tys.each do |ty|
        raise ty.inspect unless ty.is_a?(Type)
        types[ty] = true
      end
      super(types)
    end

    def on_type_added(genv, src_var, added_types)
      # TODO: need to report error?
    end

    def on_type_removed(genv, src_var, removed_types)
    end

    def new_vertex(genv, show_name, node)
      nvtx = Vertex.new(show_name, node)
      add_edge(genv, nvtx)
      nvtx
    end

    def add_edge(genv, nvtx)
      nvtx.on_type_added(genv, self, @types.keys)
    end

    def remove_edge(genv, nvtx)
      nvtx.on_type_removed(genv, self, @types.keys)
    end

    def show
      if Fiber[:show_rec].include?(self)
        "...(recursive)..."
      else
        begin
          Fiber[:show_rec] << self
          ret = @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.sort.join(" | ")
        #ensure
          Fiber[:show_rec].delete(self)
          ret
        end
      end
    end

    def match?(genv, other)
      @types.each do |ty1, _source|
        other.types.each do |ty2, _source|
          return true if ty1.match?(genv, ty2)
        end
      end
      return false
    end

    def to_s
      "<src:#{ show }>"
    end

    alias inspect to_s
  end

  class Vertex < BasicVertex
    def initialize(show_name, node)
      @show_name = show_name
      case node
      when AST::Node
      when RBS::AST::Declarations::Base
      when Entity
      else
        raise
      end
      @node = node
      @next_vtxs = Set[]
      super({})
    end

    attr_reader :show_name, :next_vtxs, :types

    def on_type_added(genv, src_var, added_types)
      new_added_types = []
      added_types.each do |ty|
        unless @types[ty]
          @types[ty] ||= Set[]
          new_added_types << ty
        end
        raise "duplicated edge" if @types[ty].include?(src_var)
        @types[ty] << src_var
      end
      unless new_added_types.empty?
        @next_vtxs.each do |nvtx|
          nvtx.on_type_added(genv, self, new_added_types)
        end
      end
    end

    def on_type_removed(genv, src_var, removed_types)
      new_removed_types = []
      removed_types.each do |ty|
        @types[ty].delete(src_var)
        if @types[ty].empty?
          @types.delete(ty)
          new_removed_types << ty
        end
      end
      unless new_removed_types.empty?
        @next_vtxs.each do |nvtx|
          nvtx.on_type_removed(genv, self, new_removed_types)
        end
      end
    end

    def new_vertex(genv, show_name, node)
      nvtx = Vertex.new(show_name, node)
      add_edge(genv, nvtx)
      nvtx
    end

    def add_edge(genv, nvtx)
      @next_vtxs << nvtx
      nvtx.on_type_added(genv, self, @types.keys) unless @types.empty?
    end

    def remove_edge(genv, nvtx)
      @next_vtxs.delete(nvtx)
      nvtx.on_type_removed(genv, self, @types.keys) unless @types.empty?
    end

    def match?(genv, other)
      @types.each do |ty1, _source|
        other.types.each do |ty2, _source|
          # XXX
          return true if ty1.base_types(genv).first.match?(genv, ty2.base_types(genv).first)
        end
      end
      return false
    end

    $new_id = 0 # TODO: Use class variable

    def to_s
      "v#{ @id ||= $new_id += 1 }"
    end

    alias inspect to_s

    def long_inspect
      "#{ to_s } (#{ @show_name } @ #{ @node.code_range })"
    end
  end

  class NilFilter
    def initialize(genv, node, prev_vtx, allow_nil)
      @node = node
      @next_vtx = Vertex.new("#{ prev_vtx.show_name }:filter", node)
      prev_vtx.add_edge(genv, self)
      @allow_nil = allow_nil
    end

    attr_reader :show_name, :node, :next_vtx, :allow_nil

    def filter(types)
      types.select {|ty| (ty == Type.nil) == @allow_nil }
    end

    def on_type_added(genv, src_var, added_types)
      types = filter(added_types)
      @next_vtx.on_type_added(genv, self, types) unless types.empty?
    end

    def on_type_removed(genv, src_var, removed_types)
      types = filter(removed_types)
      @next_vtx.on_type_removed(genv, self, types) unless types.empty?
    end

    #@@new_id = 0

    def to_s
      "NF#{ @id ||= $new_id += 1 } -> #{ @next_vtx }"
    end
  end

  class IsAFilter
    def initialize(genv, node, prev_vtx, neg, const_read)
      @node = node
      @types = Set[]
      @next_vtx = Vertex.new("#{ prev_vtx.show_name }:filter", node)
      prev_vtx.add_edge(genv, self)
      @neg = neg
      @const_read = const_read
      @const_read.const_reads << self
    end

    attr_reader :node, :next_vtx

    def filter(genv, types)
      # TODO: @const_read may change
      types.select {|ty| ty.base_types(genv).any? {|base_ty| genv.subclass?(base_ty.cpath, @const_read.cpath) != @neg } }
    end

    def on_type_added(genv, src_var, added_types)
      added_types.each do |ty|
        @types << ty
      end
      run(genv)
    end

    def on_type_removed(genv, src_var, removed_types)
      removed_types.each do |ty|
        @types.delete(ty)
      end
      run(genv)
    end

    def run(genv)
      if @const_read.cpath
        passed_types = []
        @types.each do |ty|
          if ty.base_types(genv).any? {|base_ty| genv.subclass?(base_ty.cpath, @const_read.cpath) } != @neg
            passed_types << ty
          end
        end
      else
        passed_types = @types.to_a
      end
      added_types = passed_types - @next_vtx.types.keys
      removed_types = @next_vtx.types.keys - passed_types
      @next_vtx.on_type_added(genv, self, added_types)
      @next_vtx.on_type_removed(genv, self, removed_types)
    end

    #@@new_id = 0

    def to_s
      "NF#{ @id ||= $new_id += 1 } -> #{ @next_vtx }"
    end
  end

  class BotFilter
    def initialize(genv, node, prev_vtx, base_vtx)
      @node = node
      @types = {}
      @prev_vtx = prev_vtx
      @next_vtx = Vertex.new("#{ prev_vtx.show_name }:botfilter", node)
      @base_vtx = base_vtx
      base_vtx.add_edge(genv, self)
      prev_vtx.add_edge(genv, self)
    end

    attr_reader :node, :types, :prev_vtx, :next_vtx, :base_vtx

    def filter(types)
      types.select {|ty| (ty == Type.nil) == @allow_nil }
    end

    def on_type_added(genv, src_var, added_types)
      if src_var == @base_vtx
        if @base_vtx.types.size == 1 && @base_vtx.types.include?(Type::Bot.new)
          @next_vtx.on_type_removed(genv, self, @types.keys & @next_vtx.types.keys) # XXX: smoke/control/bot2.rb
        end
      else
        added_types.each do |ty|
          @types[ty] = true
        end
        if @base_vtx.types.size == 1 && @base_vtx.types.include?(Type::Bot.new)
          # ignore
        else
          @next_vtx.on_type_added(genv, self, added_types - @next_vtx.types.keys) # XXX: smoke/control/bot4.rb
        end
      end
    end

    def on_type_removed(genv, src_var, removed_types)
      if src_var == @base_vtx
        if @base_vtx.types.size == 1 && @base_vtx.types.include?(Type::Bot.new)
          # ignore
        else
          @next_vtx.on_type_added(genv, self, @types.keys - @next_vtx.types.keys) # XXX: smoke/control/bot4.rb
        end
      else
        removed_types.each do |ty|
          @types.delete(ty) || raise
        end
        if @base_vtx.types.size == 1 && @base_vtx.types.include?(Type::Bot.new)
          # ignore
        else
          @next_vtx.on_type_removed(genv, self, removed_types & @next_vtx.types.keys) # XXX: smoke/control/bot2.rb
        end
      end
    end

    #@@new_id = 0

    def to_s
      "BF#{ @id ||= $new_id += 1 } -> #{ @next_vtx }"
    end
  end

  class Box
    def initialize(node)
      @node = node
      @edges = Set[]
      @destroyed = false
    end

    attr_reader :node

    def destroy(genv)
      @destroyed = true
      @edges.each do |src, dst|
        src.remove_edge(genv, dst)
      end
    end

    def on_type_added(genv, src_tyvar, added_types)
      genv.add_run(self)
    end

    def on_type_removed(genv, src_tyvar, removed_types)
      genv.add_run(self)
    end

    def run(genv)
      return if @destroyed
      new_edges = run0(genv)

      # install
      new_edges.each do |src, dst|
        src.add_edge(genv, dst) unless @edges.include?([src, dst])
      end

      # uninstall
      @edges.each do |src, dst|
        src.remove_edge(genv, dst) unless new_edges.include?([src, dst])
      end

      @edges = new_edges
    end

    #@@new_id = 0

    def to_s
      "#{ self.class.to_s.split("::").last[0] }#{ @id ||= $new_id += 1 }"
    end

    alias inspect to_s
  end

  class ConstReadSite < Box
    def initialize(node, genv, const_read)
      super(node)
      @const_read = const_read
      const_read.const_reads << self
      @ret = Vertex.new("cname", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv)
      cdef = @const_read.cdef
      if cdef && cdef.vtx
        Set[[cdef.vtx, @ret]]
      else
        Set[]
      end
    end

    def long_inspect
      "#{ to_s } (cname:#{ @cname } @ #{ @node.code_range })"
    end
  end

  class CallSite < Box
    def initialize(node, genv, recv, mid, a_args, block)
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
      @diagnostics = []
    end

    attr_reader :recv, :mid, :a_args, :block, :ret

    def run0(genv)
      edges = Set[]
      @diagnostics.clear
      resolve(genv) do |recv_ty, mid, me, param_map|
        if !me
          # TODO: undefined method error
          cr = @node.mid_code_range || @node
          @diagnostics << TypeProf::Diagnostic.new(cr, "undefined method: #{ recv_ty.show }##{ @mid }")
        elsif me.builtin
          # TODO: block? diagnostics?
          new_edges = me.builtin[@node, recv_ty, @a_args, @ret]
          new_edges.each {|src, dst| edges << [src, dst] }
        elsif !me.decls.empty?
          # TODO: support "| ..."
          me.decls.each do |mdecl|
            # TODO: union type is ok?
            new_edges, diagnostics = mdecl.resolve_overloads(genv, @node, param_map, @a_args, @block, @ret)
            new_edges.each {|src, dst| edges << [src, dst] }
            @diagnostics.concat(diagnostics)
          end
        elsif !me.defs.empty?
          me.defs.each do |mdef|
            new_edges, diagnostics = mdef.call(genv, @node, @a_args, @block, @ret)
            new_edges.each {|src, dst| edges << [src, dst] }
            @diagnostics.concat(diagnostics)
          end
        else
          pp me
          raise
        end
      end
      edges
    end

    def resolve(genv)
      @recv.types.each do |ty, _source|
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
          while true
            me = genv.resolve_meth(cpath, singleton, mid)
            if !me.aliases.empty?
              mid = me.aliases.to_a.first
              redo
            end
            if me && me.exist?
              found = true
              break
            end

            unless singleton # TODO
              genv.resolve_cpath(cpath).include_module_cpaths.each do |mod_cpath|
                me = genv.resolve_meth(mod_cpath, singleton, mid)
                if !me.aliases.empty?
                  mid = me.aliases.to_a.first
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
            # superclass
            if cpath == [:BasicObject]
              if singleton
                singleton = false
                cpath = [:Class]
              else
                break
              end
            else
              cpath = genv.resolve_cpath(cpath).superclass_cpath
              unless cpath
                cpath = [:Module]
                singleton = false
              end
            end
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
      @diagnostics[0, 3].each do |diag|
        yield diag
      end
      if @diagnostics.size >= 4
        TypeProf::Diagnostic.new(@node.mid_code_range || @node, "(and #{ @diagnostics.size - 3 } errors omitted)")
      end
    end

    def long_inspect
      "#{ to_s } (mid:#{ @mid } @ #{ @node.code_range })"
    end
  end

  class GVarReadSite < Box
    def initialize(node, genv, name)
      super(node)
      @vtx = genv.resolve_gvar(name).vtx
      @ret = Vertex.new("gvar", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv)
      [[@vtx, @ret]]
    end

    def long_inspect
      "TODO"
    end
  end

  class IVarReadSite < Box
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

    def run0(genv)
      cur_ive = genv.resolve_ivar(@cpath, @singleton, @name)
      cpath = @cpath
      target_vtx = nil
      while cpath
        ive = genv.resolve_ivar(cpath, @singleton, @name)
        if ive.exist?
          target_vtx = ive.vtx
        end
        break if cpath == [:BasicObject]
        cpath = genv.resolve_cpath(cpath).superclass_cpath
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
      edges
    end

    def long_inspect
      "IVarTODO"
    end
  end

  class MAsgnSite < Box
    def initialize(node, genv, rhs, lhss)
      super(node)
      @rhs = rhs
      @lhss = lhss
      @rhs.add_edge(genv, self)
    end

    attr_reader :node, :rhs, :lhss

    def ret = @rhs

    def run0(genv)
      edges = []
      @rhs.types.each do |ty, _source|
        case ty
        when Type::Array
          @lhss.each_with_index do |lhs, i|
            edges << [ty.get_elem(i), lhs]
          end
        else
          edges << [@rhs, @lhss[0]]
        end
      end
      edges
    end

    def long_inspect
      "#{ to_s } (masgn)"
    end
  end
end