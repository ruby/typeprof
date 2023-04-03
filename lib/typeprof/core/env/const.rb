module TypeProf::Core
  class ConstRead
    def initialize(cname)
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
        when ModuleEntity
          follower.on_parent_modules_changed(genv)
        else
          raise follower.inspect
        end
      end
    end

    def destroy(genv)
      @event_sources.each do |mod|
        mod.const_reads.delete(self)
      end
      @event_sources.clear
    end

    def resolve(genv, cref, break_object)
      destroy(genv)

      first = true
      while cref
        scope = cref.cpath
        mod = genv.resolve_cpath(scope)
        while true
          @event_sources << mod
          mod.const_reads << self
          inner_mod = genv.resolve_cpath(mod.cpath + [@cname]) # TODO
          if inner_mod.exist?
            cpath = mod.cpath + [@cname]
            return [cpath, mod.consts[@cname]]
          end
          if mod.consts[@cname] && mod.consts[@cname].exist?
            return [nil, mod.consts[@cname]]
          end
          # TODO: include
          break unless first
          break unless mod.superclass
          break if mod.cpath == [:BasicObject]
          mod = mod.superclass
          break if mod.cpath == [] && break_object
        end
        first = false
        cref = cref.outer
      end
      return nil
    end
  end

  class BaseConstRead < ConstRead
    def initialize(genv, cname, cref)
      super(cname)
      @cref = cref
      genv.add_static_eval_queue(:const_read_changed, self)
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
    def initialize(genv, cname, cbase)
      super(cname)
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