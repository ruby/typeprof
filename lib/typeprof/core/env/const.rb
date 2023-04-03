module TypeProf::Core
  class ConstRead
    def initialize(node, cname)
      @node = node
      @cname = cname
      @followers = Set[]
      @cpath = nil
      @cdef = nil
      @event_sources = []
    end

    attr_reader :cref, :cname, :cpath, :cdef, :followers

    def propagate(genv)
      @followers.dup.each do |follower|
        case follower
        when ScopedConstRead
          follower.on_cbase_updated(genv)
        when ConstReadSite, IsAFilter
          genv.add_run(follower)
        when ModuleDirectory
          follower.on_parent_module_changed(genv)
        else
          raise follower.inspect
        end
      end
    end

    def destroy(genv)
      @event_sources.each do |dir|
        dir.const_reads.delete(self)
      end
      @event_sources.clear
    end

    def resolve(genv, cref, break_object)
      destroy(genv)

      first = true
      while cref
        scope = cref.cpath
        dir = genv.resolve_cpath(scope)
        while true
          @event_sources << dir
          dir.const_reads << self
          mm = genv.resolve_cpath(dir.cpath + [@cname]) # TODO
          if mm.exist?
            cpath = dir.cpath + [@cname]
            return [cpath, dir.consts[@cname]]
          end
          if dir.consts[@cname] && dir.consts[@cname].exist?
            return [nil, dir.consts[@cname]]
          end
          # TODO: include
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
    def initialize(node, genv, cname, cref)
      super(node, cname)
      @cref = cref
      genv.const_read_changed(self)
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
    def initialize(node, genv, cname, cbase)
      super(node, cname)
      # Note: cbase may be nil when the cbase is a dynamic expression (such as lvar::CONST)
      @cbase = cbase
      @cbase.followers << self if @cbase
    end

    attr_reader :cbase

    def on_cbase_updated(genv)
      raise "should not occur" unless @cbase
      if @cbase.cpath
        cpath, cdef = resolve(genv, CRef.new(@cbase.cpath, false, nil), true)
      else
        cpath = cdef = nil
      end
      if cpath != @cpath || cdef != @cdef
        @cpath = cpath
        @cdef = cdef
        propagate(genv)
      end
    end
  end
end