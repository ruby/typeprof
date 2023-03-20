module TypeProf::Core
  Fiber[:show_rec] = Set[]

  class Source
    def initialize(ty)
      raise ty.inspect unless ty.is_a?(Type)
      @types = { ty => nil }
    end

    attr_reader :types

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
          @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.sort.join(" | ")
        ensure
          Fiber[:show_rec].delete(self)
        end
      end
    end

    def to_s
      "<src:#{ show }>"
    end

    alias inspect to_s
  end

  class Vertex
    def initialize(show_name, node)
      @show_name = show_name
      raise unless node.is_a?(AST::Node)
      @node = node
      @types = {}
      @next_vtxs = Set[]
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

    def show
      if Fiber[:show_rec].include?(self)
        "...(recursive)..."
      else
        begin
          Fiber[:show_rec] << self
          types = []
          ary_elems = []
          @types.each do |ty, _source|
            case ty
            when Type::Array
              ary_elems << ty.elem.show
            else
              types << ty.show
            end
          end
          unless ary_elems.empty?
            types << "Array[#{ ary_elems.sort.join(" | ") }]"
          end
          types.empty? ? "untyped" : types.sort.join(" | ")
        ensure
          Fiber[:show_rec].delete(self)
        end
      end
    end

    @@new_id = 0

    def to_s
      "v#{ @id ||= @@new_id += 1 }"
    end

    alias inspect to_s

    def long_inspect
      a = @node.lenv
      a = a.text_id
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
            cd.type.base_types(genv).each do |base_ty|
              edges << [Source.new(base_ty), @ret]
            end
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
        @cbase.types.each do |ty, _source|
          case ty
          when Type::Module
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
      genv.add_callsite(self)
    end

    def destroy(genv)
      genv.remove_callsite(self)
      super
    end

    attr_reader :recv, :mid, :a_args, :block, :ret

    def run0(genv)
      edges = Set[]
      resolve(genv).each do |ty, mds|
        mds.each do |md|
          case md
          when MethodDecl
            if md.builtin
              # TODO: block
              nedges = md.builtin[@node, ty, @mid, @a_args, @ret]
            else
              # TODO: handle Type::Union
              nedges = md.resolve_overloads(genv, ty, @a_args, @block, @ret)
            end
            nedges.each {|src, dst| edges << [src, dst] }
          when MethodDef
            if @block && md.block
              edges << [@block, md.block]
            end
            # check arity
            if @a_args.size == md.f_args.size
              @a_args.zip(md.f_args) do |a_arg, f_arg|
                raise unless a_arg
                raise unless f_arg
                edges << [a_arg, f_arg]
              end
            end
            edges << [md.ret, @ret]
          end
        end
      end
      edges
    end

    def resolve(genv)
      ret = []
      @recv.types.each do |ty, _source|
        ty.base_types(genv).each do |base_ty|
          mds = genv.resolve_method(base_ty.cpath, base_ty.is_a?(Type::Module), @mid)
          ret << [ty, mds] if mds
        end
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
      genv.remove_ivreadsite(self)
      super
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