module TypeProf
  class Source
    def initialize(ty)
      @types = { ty => nil }
    end

    attr_reader :types

    def add_edge(genv, nvtx)
      nvtx.on_type_added(genv, self, @types.keys)
    end

    def remove_edge(genv, nvtx)
      nvtx.on_type_removed(genv, self, @types.keys)
    end

    def show
      @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.join(" | ")
    end

    def to_s
      "<src:#{ show }>"
    end

    alias inspect to_s
  end

  class Vertex
    def initialize(show_name, node)
      @show_name = show_name
      @node = node
      @types = {}
      @next_vtxs = Set[]
      @decls = Set[]
    end

    attr_reader :show_name, :next_vtxs, :types

    def on_type_added(genv, src_var, added_types)
      new_added_types = []
      added_types.each do |ty|
        unless @types[ty]
          @types[ty] ||= Set[]
          new_added_types << ty
        end
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

    def add_edge(genv, nvtx)
      @next_vtxs << nvtx
      nvtx.on_type_added(genv, self, @types.keys) unless @types.empty?
    end

    def remove_edge(genv, nvtx)
      @next_vtxs.delete(nvtx)
      nvtx.on_type_removed(genv, self, @types.keys) unless @types.empty?
    end

    def show
      @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.join(" | ")
    end

    @@new_id = 0

    def to_s
      "v#{ @id ||= @@new_id += 1 }"
    end

    alias inspect to_s

    def long_inspect
      "#{ to_s } (#{ @show_name }; #{ @node.lenv.text_id } @ #{ @node.code_range })"
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

    @@new_id = 0

    def to_s
      "#{ self.class.to_s.split("::").last[0] }#{ @id ||= @@new_id += 1 }"
    end

    alias inspect to_s
  end

  class ConstReadSite < Box
    def initialize(node, genv, cref, cbase, cname)
      super(node)
      @cref = cref
      @cbase = cbase
      @cname = cname
      @ret = Vertex.new("cname:#{ cname }", node)
      genv.add_creadsite(self)
      @cbase.add_edge(genv, self) if @cbase
    end

    def destroy(genv)
      super
      genv.remove_creadsite(self)
    end

    attr_reader :node, :cref, :cbase, :cname, :ret

    def run0(genv)
      edges = Set[]
      resolve(genv).each do |cds|
        cds.each do |cd|
          case cd
          when ConstDecl
            ty = cd.type.base_type(genv)
            edges << [Source.new(ty), @ret]
          when ConstDef
            edges << [cd.val, @ret]
          end
        end
      end
      edges
    end

    def resolve(genv)
      ret = []
      if @cbase
        @cbase.types.each do |ty, source|
          case ty
          when Type::Class
            cds = genv.resolve_const(ty.cpath, @cname)
            ret << cds if cds
          else
            puts "???"
          end
        end
      else
        cref = @cref
        while cref
          cds = genv.resolve_const(cref.cpath, @cname)
          if cds && !cds.empty?
            ret << cds
            break
          end
          cref = cref.outer
        end
      end
      ret
    end

    def long_inspect
      "#{ to_s } (cname:#{ @cname }, #{ @node.lenv.text_id } @ #{ @node.code_range })"
    end
  end

  class CallSite < Box
    def initialize(node, genv, recv, mid, args, block)
      raise mid.to_s unless mid
      super(node)
      @recv = recv
      @mid = mid
      @args = args
      @block = block
      @ret = Vertex.new("ret:#{ mid }", node)
      genv.add_callsite(self)
      @recv.add_edge(genv, self)
      @args.add_edge(genv, self)
      #@block.add_edge(genv, self) # needed?
    end

    def destroy(genv)
      genv.remove_callsite(self)
      super
    end

    attr_reader :recv, :mid, :args, :block, :ret

    def run0(genv)
      edges = Set[]
      resolve(genv).each do |ty, mds|
        mds.each do |md|
          case md
          when MethodDecl
            if md.builtin
              # TODO: block
              md.builtin[ty, @mid, @args, @ret].each do |src, dst|
                edges << [src, dst]
              end
            else
              # TODO: block
              ret_types = md.resolve_overloads(genv, @args)
              # TODO: handle Type::Union
              ret_types.each do |ty|
                edges << [Source.new(ty), @ret]
              end
            end
          when MethodDef
            if @block && md.block
              edges << [@block, md.block]
            end
            edges << [@args, md.arg] << [md.ret, @ret]
          end
        end
      end
      edges
    end

    def resolve(genv)
      ret = []
      @recv.types.each do |ty, source|
        mds = genv.resolve_method(ty.base_type(genv).cpath, ty.is_a?(Type::Class), @mid)
        ret << [ty, mds] if mds
      end
      ret
    end

    def long_inspect
      "#{ to_s } (mid:#{ @mid }, #{ @node.lenv.text_id } @ #{ @node.code_range })"
    end
  end

  class IVarReadSite < Box
    def initialize(node, genv, cpath, singleton, name)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @name = name
      @ret = Vertex.new("ivar:#{ name }", node)
      genv.add_ivreadsite(self)
    end

    def destroy(genv)
      raise
      super
      genv.remove_ivreadsite(self)
    end

    attr_reader :node, :cpath, :singleton, :name, :ret

    def run0(genv)
      edges = Set[]
      resolve(genv).each do |ives|
        ives.each do |ive|
          case ive
          when IVarDef
            edges << [ive.val, @ret]
          end
        end
      end
      edges
    end

    def resolve(genv)
      ret = []
      ives = genv.resolve_ivar(@cpath, @singleton, @name)
      ret << ives if ives && !ives.empty?
      ret
    end

    def long_inspect
      "#{ to_s } (cname:#{ @cname }, #{ @node.lenv.text_id } @ #{ @node.code_range })"
    end
  end
end