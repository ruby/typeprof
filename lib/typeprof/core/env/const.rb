module TypeProf::Core
  class ConstRead
    def initialize(node, cname)
      @node = node
      @cname = cname
      @const_reads = Set[]
      @cpath = nil
      @cdef = nil
    end

    attr_reader :cref, :cname, :cpath, :cdef, :const_reads

    def propagate(genv)
      @const_reads.dup.each do |const_read|
        case const_read
        when ScopedConstRead
          const_read.on_cbase_updated(genv)
        when Array
          genv.resolve_cpath(const_read).on_superclass_updated(genv)
        when ConstReadSite, IsAFilter
          genv.add_run(const_read)
        else
          raise const_read.inspect
        end
      end
    end

    def resolve(genv, cref)
      first = true
      while cref
        scope = cref.cpath
        while true
          m = genv.resolve_cpath(scope)
          mm = genv.resolve_cpath(scope + [@cname])
          if !mm.module_decls.empty? || !mm.module_defs.empty?
            cpath = scope + [@cname]
          end
          if m.child_consts[@cname] && (!m.child_consts[@cname].decls.empty? || !m.child_consts[@cname].defs.empty?) # TODO: const_decls
            cdef = m.child_consts[@cname]
          end
          return [cpath, cdef] if cpath || cdef
          break unless first
          break unless m.superclass_cpath
          break if scope == [:BasicObject]
          scope = m.superclass_cpath
        end
        first = false
        cref = cref.outer
      end
      return nil
    end
  end

  class BaseConstRead < ConstRead
    def initialize(node, cname, cref)
      super(node, cname)
      @cref = cref
    end

    attr_reader :cref

    def on_scope_updated(genv)
      cpath, cdef = resolve(genv, @cref)
      if cpath != @cpath || cdef != @cdef
        @cpath = cpath
        @cdef = cdef
        propagate(genv)
      end
    end
  end

  class ScopedConstRead < ConstRead
    def initialize(node, cname, cbase)
      super(node, cname)
      @cbase = cbase
      @cbase.const_reads << self if @cbase
      @cbase_cpath = nil
    end

    attr_reader :cbase

    def on_cbase_updated(genv)
      if @cbase && @cbase.cpath
        cpath, cdef = resolve(genv, CRef.new(@cbase.cpath, false, nil))
        if cpath != @cpath || cdef != @cdef
          genv.resolve_cpath(@cbase_cpath).const_reads.delete(self) if @cbase_cpath
          @cpath = cpath
          @cdef = cdef
          @cbase_cpath = @cbase.cpath
          genv.resolve_cpath(@cbase_cpath).const_reads << self if @cbase_cpath
          propagate(genv)
        end
      end
    end
  end

  class ConstEntity
    def initialize
      @decls = Set[]
      @defs = Set[]
      @vtx = Vertex.new("const-def", self)
    end

    attr_reader :decls, :defs, :vtx

    def add_decl(decl, vtx)
      @decls << decl
      @vtx = vtx # TODO
    end

    def remove_decl(decl)
      @decls.delete(decl)
    end

    def add_def(node)
      @defs << node
      self
    end

    def remove_def(node)
      @defs.delete(node)
    end
  end
end