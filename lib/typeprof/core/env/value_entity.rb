module TypeProf::Core
  class ValueEntity
    def initialize
      @decls = Set[]
      @defs = Set[]
      @vtx = Vertex.new("gvar", self)
    end

    attr_reader :decls, :defs, :vtx

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
  end
end