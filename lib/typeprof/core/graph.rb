module TypeProf::Core
  Fiber[:show_rec] = Set[]

  class Source
    def initialize(*tys)
      @types = {}
      tys.each do |ty|
        raise ty.inspect unless ty.is_a?(Type)
        @types[ty] = true
      end
    end

    attr_reader :types

    def on_type_added(genv, src_var, added_types)
      # TODO: need to report error
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
          @types.empty? ? "untyped" : @types.keys.map {|ty| ty.show }.sort.join(" | ")
        ensure
          Fiber[:show_rec].delete(self)
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
          @types.each do |ty, _source|
            types << ty.show
          end
          types.empty? ? "untyped" : types.uniq.sort.join(" | ")
        ensure
          Fiber[:show_rec].delete(self)
        end
      end
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
      @diagnostics = nil
    end

    def destroy(genv)
      genv.remove_callsite(self)
      super
    end

    attr_reader :recv, :mid, :a_args, :block, :ret

    def run0(genv)
      edges = Set[]
      resolve(genv) do |ty, mds|
        next unless mds
        mds.each do |md|
          case md
          when MethodDecl
            if md.builtin
              # TODO: block
              nedges = md.builtin[@node, ty, @mid, @a_args, @ret]
            else
              # TODO: handle Type::Union
              nedges = md.resolve_overloads(@node, genv, ty, @a_args, @block, @ret)
            end
            nedges.each {|src, dst| edges << [src, dst] }
          when MethodDef
            if @block && md.block
              edges << [@block, md.block]
            end
            # check arity
            @a_args.zip(md.f_args) do |a_arg, f_arg|
              break unless f_arg
              edges << [a_arg, f_arg]
            end
            edges << [md.ret, @ret]
          end
        end
      end
      edges
    end

    def resolve(genv)
      @recv.types.each do |ty, _source|
        ty.base_types(genv).each do |base_ty|
          mds = genv.resolve_method(base_ty.cpath, base_ty.is_a?(Type::Module), @mid)
          yield ty, mds
        end
      end
    end

    def diagnostics(genv)
      resolve(genv) do |ty, mds|
        if mds
          mds.each do |md|
            case md
            when MethodDecl
            when MethodDef
              if @a_args.size != md.f_args.size
                yield TypeProf::Diagnostic.new(@node, "wrong number of arguments (#{ @a_args.size } for #{ md.f_args.size })")
              end
            end
          end
          # TODO: arity error, type error
        else
          yield TypeProf::Diagnostic.new(@node, "undefined method: #{ ty.show }##{ @mid }")
        end
      end
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

    attr_reader :cpath, :singleton, :name, :ret

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