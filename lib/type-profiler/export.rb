module TypeProfiler
  class RubySignatureExporter
    def initialize(scratch, errors, gvar_write, ivar_write, signatures, yields, backward_edges)
      @scratch = scratch
      @errors = errors
      @signatures = signatures
      @yields = yields
      @backward_edges = backward_edges
      @gvar_write = gvar_write
      @ivar_write = ivar_write
    end

    def show_signature(farg_tys, ret_tys)
      s = "(#{ farg_tys.join(", ") }) -> "
      s + (ret_tys.size == 1 ? ret_tys.first : "(#{ ret_tys.join(" | ") })")
    end

    def show_block(ctx)
      blk_tys = {}
      @yields[ctx].each do |blk_ctx|
        blk_fargs = blk_ctx.sig.fargs.lead_tys.map {|ty| ty.screen_name(@scratch) } # XXX: other arguments but lead_tys?
        if @yields[blk_ctx]
          blk_fargs << show_block(blk_ctx)
        end
        blk_rets = {}
        @signatures[blk_ctx].each do |blk_ret_ty|
          blk_rets[blk_ret_ty.screen_name(@scratch)] = true
        end
        blk_tys["Proc[#{ show_signature(blk_fargs, blk_rets.keys) }]"] = true
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

    def show(stat_eps)
      out = []
      @errors.each do |ep, msg|
        if ENV["TYPE_PROFILER_DETAIL"]
          backtrace = filter_backtrace(generate_analysis_trace(ep, {}))
        else
          backtrace = [ep]
        end
        loc, *backtrace = backtrace.map do |ep|
          ep.source_location
        end
        out << "#{ loc }: #{ msg }"
        backtrace.each do |loc|
          out << "        from #{ loc }"
        end
      end
      h = {}
      @gvar_write.each do |var, tys|
        tys.each do |ty|
          gvar_name = var
          ret = ty.screen_name(@scratch)
          h[gvar_name] ||= {}
          h[gvar_name][ret] ||= {}
        end
      end
      h.each do |gvar_name, tys|
        out << "#{ gvar_name } :: #{ tys.keys.join(" | ") }"
      end
      h = {}
      @ivar_write.each do |(recv, var), tys|
        tys.each do |ty|
          ivar_name = "#{ recv.screen_name(@scratch) }##{ var }"
          ret = ty.screen_name(@scratch)
          h[ivar_name] ||= {}
          h[ivar_name][ret] ||= {}
        end
      end
      h.each do |ivar_name, tys|
        out << "#{ ivar_name } :: #{ tys.keys.join(" | ") }"
      end
      h = {}
      stat_classes = {}
      stat_methods = {}
      @signatures.each do |ctx, ret_tys|
        next unless ctx.sig.mid
        next unless ctx.iseq
        ret_tys.each do |ret_ty|
          recv = ctx.cref.klass
          recv = Type::Instance.new(recv) unless ctx.sig.singleton
          recv = recv.screen_name(@scratch)
          stat_classes[recv] = true
          method_name = "#{ recv }##{ ctx.sig.mid }"
          stat_methods[method_name] = true
          fargs = ctx.sig.fargs.screen_name(@scratch)
          if @yields[ctx]
            fargs << show_block(ctx)
          end
          ret = ret_ty.screen_name(@scratch)
          h[method_name] ||= {}
          h[method_name][fargs] ||= {}
          h[method_name][fargs][ret] = true
        end
      end
      h.each do |method_name, sigs|
        sigs.each do |fargs, rets|
          out << "#{ method_name } :: #{ show_signature(fargs, rets.keys) }"
        end
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
      puts(*out)
    end
  end
end
