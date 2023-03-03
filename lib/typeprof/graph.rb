module TypeProf
  class Vertex
    def initialize(show_name, node)
      @show_name = show_name
      @node = node
      @types = {}
      @next_vtxs = Set.new
      @decls = Set.new
    end

    attr_reader :show_name, :next_vtxs, :types

    def on_type_added(genv, src_var, added_types)
      new_added_types = []
      added_types.each do |ty|
        unless @types[ty]
          @types[ty] ||= Set.new
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
      "<fixed>"
    end

    alias inspect to_s
  end

  class ReadSite
    def initialize(genv, node, cref, cbase, cname)
      @node = node
      @cref = cref
      @cbase = cbase
      @cname = cname
      @ret = Vertex.new("cname:#{ cname }", node)
      genv.add_readsite(self)
      genv.add_run(self)
      @cbase.add_edge(genv, self) if @cbase
      @edges = Set.new
    end

    def on_type_added(genv, src_tyvar, added_types)
      genv.add_run(self)
    end

    def on_type_removed(genv, src_tyvar, removed_types)
      genv.add_run(self)
    end

    attr_reader :node, :cref, :cbase, :cname, :ret

    def run(genv)
      destroy(genv)

      resolve(genv).each do |cds|
        cds.each do |cd|
          case cd
          when ConstDecl
            # TODO
            raise
          when ConstDef
            @edges << [cd.val, @ret]
          end
        end
      end

      @edges.each do |src_tyvar, dest_tyvar|
        src_tyvar.add_edge(genv, dest_tyvar)
      end
    end

    def destroy(genv)
      @edges.each do |src_tyvar, dest_tyvar|
        src_tyvar.remove_edge(genv, dest_tyvar)
      end
      @edges.clear
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

    @@new_id = 0

    def to_s
      "R#{ @id ||= @@new_id += 1 }"
    end

    alias inspect to_s

    def long_inspect
      "#{ to_s } (cname:#{ @cname }, #{ @node.lenv.text_id } @ #{ @node.code_range })"
    end
  end

  class CallSite
    def initialize(genv, node, recv, mid, args)
      raise mid.to_s unless mid
      @node = node
      @recv = recv
      @mid = mid
      @args = args
      @ret = Vertex.new("ret:#{ mid }", node)
      @edges = Set.new
      genv.add_callsite(self)
      genv.add_run(self)
      @recv.add_edge(genv, self)
      @args.add_edge(genv, self)
    end

    attr_reader :node, :recv, :mid, :args, :ret

    def on_type_added(genv, src_tyvar, added_types)
      genv.add_run(self)
    end

    def on_type_removed(genv, src_tyvar, removed_types)
      genv.add_run(self)
    end

    def run(genv)
      destroy(genv)

      resolve(genv).each do |ty, mds|
        mds.each do |md|
          case md
          when MethodDecl
            if md.builtin
              md.builtin[ty, @mid, @args, @ret].each do |src, dest|
                @edges << [src, dest]
              end
            else
              ret_types = md.resolve_overloads(genv, @args)
              # TODO: handle Type::Union
              ret_types.each do |ty|
                @edges << [Source.new(ty), @ret]
              end
            end
          when MethodDef
            @edges << [@args, md.arg] << [md.ret, @ret]
          end
        end
      end

      @edges.each do |src_tyvar, dest_tyvar|
        src_tyvar.add_edge(genv, dest_tyvar)
      end
    end

    def destroy(genv)
      @edges.each do |src_tyvar, dest_tyvar|
        src_tyvar.remove_edge(genv, dest_tyvar)
      end
      @edges.clear
    end

    def resolve(genv)
      ret = []
      @recv.types.each do |ty, source|
        # TODO: resolve ty#mid
        # assume ty is a Type::Instnace or Type::Class
        mds = genv.resolve_method(ty.cpath, ty.is_a?(Type::Class), @mid)
        ret << [ty, mds] if mds
      end
      ret
    end

    @@new_id = 0

    def to_s
      "C#{ @id ||= @@new_id += 1 }"
    end

    alias inspect to_s

    def long_inspect
      "#{ to_s } (mid:#{ @mid }, #{ @node.lenv.text_id } @ #{ @node.code_range })"
    end
  end
end