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
        dir = genv.resolve_cpath(scope)
        while true
          mm = genv.resolve_cpath(dir.cpath + [@cname]) # TODO
          if mm.exist?
            cpath = dir.cpath + [@cname]
            return [cpath, dir.consts[@cname]]
          end
          if dir.consts[@cname] && dir.consts[@cname].exist?
            return [nil, dir.consts[@cname]]
          end
          break unless first
          break unless dir.superclass
          break if dir.cpath == [:BasicObject]
          dir = dir.superclass
          break if dir.cpath == [] && break_object
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
      # Note: cbase may be nil when the cbase is a dynamic expression (such as lvar::CONST)
      @cbase.const_reads << self if @cbase
      @cbase_cpath = nil
    end

    attr_reader :cbase

    def on_cbase_updated(genv)
      raise "should not occur" unless @cbase
      cpath, cdef = resolve(genv, CRef.new(@cbase.cpath, false, nil), true) if @cbase.cpath
      if @cbase_cpath != @cbase.cpath || cpath != @cpath || cdef != @cdef
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