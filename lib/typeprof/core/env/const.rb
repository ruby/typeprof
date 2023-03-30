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

    def resolve(genv, cref, break_object)
      first = true
      while cref
        scope = cref.cpath
        while true
          m = genv.resolve_cpath(scope)
          mm = genv.resolve_cpath(scope + [@cname])
          if !mm.module_decls.empty? || !mm.module_defs.empty?
            cpath = scope + [@cname]
          end
          if m.child_consts[@cname] && m.child_consts[@cname].exist?
            cdef = m.child_consts[@cname]
          end
          return [cpath, cdef] if cpath || cdef
          break unless first
          break unless m.superclass_cpath
          break if scope == [:BasicObject]
          scope = m.superclass_cpath
          break if scope == [] && break_object
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
      cpath, cdef = resolve(genv, @cref, false)
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
        cpath, cdef = resolve(genv, CRef.new(@cbase.cpath, false, nil), true)
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
end