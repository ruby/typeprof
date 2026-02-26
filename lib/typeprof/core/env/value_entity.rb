module TypeProf::Core
  class ValueEntity
    def initialize
      @decls = Set.empty
      @defs = Set.empty
      @read_boxes = Set.empty
      @vtx = Vertex.new(self)
    end

    attr_reader :decls, :defs, :read_boxes, :vtx

    def add_decl(decl)
      @decls << decl
    end

    def remove_decl(decl)
      @decls.delete(decl) || raise
    end

    def add_def(def_)
      @defs << def_
    end

    def remove_def(def_)
      @defs.delete(def_) || raise
    end

    def exist?
      !@decls.empty? || !@defs.empty?
    end

    def on_const_added(genv, cpath)
      unless exist?
        parent_mod = genv.resolve_cpath(cpath[0..-2])
        genv.add_static_eval_queue(:inner_modules_changed, [parent_mod, cpath[-1]])
      end
    end

    def on_const_removed(genv, cpath)
      unless exist?
        parent_mod = genv.resolve_cpath(cpath[0..-2])
        genv.add_static_eval_queue(:inner_modules_changed, [parent_mod, cpath[-1]])
      end
    end
  end
end
