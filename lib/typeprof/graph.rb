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
end