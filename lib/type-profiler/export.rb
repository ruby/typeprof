module TypeProfiler
  class RubySignatureExporter
    def initialize(scratch, errors, gvar_write, ivar_write, cvar_write, sig_fargs, sig_ret, yields, backward_edges)
      @scratch = scratch
      @errors = errors
      @sig_fargs = sig_fargs
      @sig_ret = sig_ret
      @yields = yields
      @backward_edges = backward_edges
      @gvar_write = gvar_write
      @ivar_write = ivar_write
      @cvar_write = cvar_write
    end

    def show_types(tys)
      tys = tys.to_a
      if tys.empty?
        "bot"
      else
        tys.map {|ty| ty.screen_name(@scratch) }.sort.uniq.join(" | ")
      end
    end

    def show_signature(farg_tys, ret_ty)
      s = "(#{ farg_tys.join(", ") }) -> "
      ret_tys = ret_ty.screen_name(@scratch)
      s + (ret_tys.include?("|") ? "(#{ ret_tys })" : ret_tys)
    end

    def show_block(ctx)
      blk_tys = {}
      @yields[ctx].each do |blk_ctx, fargs|
        blk_fargs = fargs.lead_tys.map {|ty| ty.screen_name(@scratch) } # XXX: other arguments but lead_tys?
        if @yields[blk_ctx]
          blk_fargs << show_block(blk_ctx)
        end
        blk_tys["Proc[#{ show_signature(blk_fargs, @sig_ret[blk_ctx]) }]"] = true
      end
      blk_tys.size == 1 ? "&#{ blk_tys.keys.first }" : "&(#{ blk_tys.keys.join(" & ") })"
    end

    def generate_analysis_trace(state, visited)
      return nil if visited[state]
      visited[state] = true
      prev_states = @backward_edges[state]
      if prev_states
        prev_states.each_key do |pstate|
          trace = generate_analysis_trace(pstate, visited)
          return [state] + trace if trace
        end
        nil
      else
        []
      end
    end

    def filter_backtrace(trace)
      ntrace = [trace.first]
      trace.each_cons(2) do |ep1, ep2|
        ntrace << ep2 if ep1.ctx != ep2.ctx
      end
      ntrace
    end

    def show_errors
      return if @errors.empty?

      puts "# Errors"
      @errors.each do |ep, msg|
        if ENV["TYPE_PROFILER_DETAIL"]
          backtrace = filter_backtrace(generate_analysis_trace(ep, {}))
        else
          backtrace = [ep]
        end
        loc, *backtrace = backtrace.map do |ep|
          ep.source_location
        end
        puts "#{ loc }: #{ msg }"
        backtrace.each do |loc|
          puts "        from #{ loc }"
        end
      end
      puts
    end

    def show_gvars
      return if @gvar_write.empty?

      puts "# Global variables"
      @gvar_write.each do |gvar_name, tys|
        puts "#{ gvar_name } : #{ tys.screen_name(@scratch) }"
      end
      puts
    end

    def show_class_or_module(obj, classes)
      kind = obj.klass.kind
      name = obj.screen_name(@scratch)
      classes[name] ||= { kind: kind, ivars: {}, cvars: {}, methods: {} }
    end

    def show(stat_eps)
      show_errors
      show_gvars

      stat_classes = {}
      stat_methods = {}
      classes = {}
      @ivar_write.each do |(recv, var), ty|
        entry = show_class_or_module(recv, classes)
        entry[:ivars][var] = ty.screen_name(@scratch)
      end
      @cvar_write.each do |(klass, var), ty|
        entry = show_class_or_module(Type::Instance.new(klass), classes)
        entry[:cvars][var] = ty.screen_name(@scratch)
      end
      @sig_fargs.each do |ctx, fargs|
        next unless ctx.mid && ctx.iseq && fargs
        ret_tys = @sig_ret[ctx]

        entry = show_class_or_module(Type::Instance.new(ctx.cref.klass), classes)

        method_name = ctx.mid
        method_name = "self.#{ method_name }" if ctx.singleton

        fargs = fargs.screen_name(@scratch)
        if @yields[ctx]
          fargs << show_block(ctx)
        end

        entry[:methods][method_name] ||= []
        entry[:methods][method_name] << show_signature(fargs, ret_tys)

        #stat_classes[recv] = true
        #stat_methods[[recv, method_name]] = true
      end

      puts "# Classes" # and Modules
      first = true
      classes.each do |recv, cls|
        puts unless first
        first = false
        puts "#{ cls[:kind] } #{ recv }"
        cls[:ivars].each do |var, tys|
          puts "  #{ var } : #{ tys }"
        end
        cls[:cvars].each do |var, tys|
          puts "  #{ var } : #{ tys }"
        end
        cls[:methods].each do |method_name, sigs|
          sigs = sigs.sort.join("\n" + " " * (method_name.size + 3) + "| ")
          puts "  #{ method_name } : #{ sigs }"
        end
        puts "end"
      end

      if ENV["TP_STAT"]
        puts "statistics:"
        puts "  %d execution points" % stat_eps.size
        puts "  %d classes" % stat_classes.size
        puts "  %d methods (in total)" % stat_methods.size
      end
      if ENV["TP_COVERAGE"]
        coverage = {}
        stat_eps.each do |ep|
          path = ep.ctx.iseq.path
          lineno = ep.ctx.iseq.linenos[ep.pc] - 1
          (coverage[path] ||= [])[lineno] ||= 0
          (coverage[path] ||= [])[lineno] += 1
        end
        File.binwrite("coverage.dump", Marshal.dump(coverage))
      end
    end
  end
end
