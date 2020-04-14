module TypeProfiler
  module Reporters
    module_function

    def generate_analysis_trace(state, visited, backward_edge)
      return nil if visited[state]
      visited[state] = true
      prev_states = backward_edges[state]
      if prev_states
        prev_states.each_key do |pstate|
          trace = generate_analysis_trace(pstate, visited, backward_edge)
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

    def show_error(errors, backward_edge)
      return if errors.empty?

      puts "# Errors"
      errors.each do |ep, msg|
        if ENV["TYPE_PROFILER_DETAIL"]
          backtrace = filter_backtrace(generate_analysis_trace(ep, {}, backward_edge))
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

    def show_reveal_types(scratch, reveal_types)
      return if reveal_types.empty?

      puts "# Revealed types"
      reveal_types.each do |source_location, ty|
        puts "#  #{ source_location } #=> #{ ty.screen_name(scratch) }"
      end
      puts
    end

    def show_gvars(scratch, gvar_write)
      # A signature for global variables is not supported in RBS
      return if gvar_write.empty?

      puts "# Global variables"
      gvar_write.each do |gvar_name, tys|
        puts "#  #{ gvar_name } : #{ tys.screen_name(scratch) }"
      end
      puts
    end
  end

  class RubySignatureExporter2
    class Module
      def initialize(name, kind)
        @name = name
        @kind = kind
        @includes = []
        @ivars = {}
        @cvars = {}
        @methods = {}
      end

      def add_includes(included_mods)
        @includes.concat(included_mods)
      end

      def add_ivar(name, ty)
        @ivars[name] = ty
      end

      def add_cvar(name, ty)
        @cvars[name] = ty
      end
    end

    def initialize(scratch)
      @scratch = scratch
      @mods = {}
    end

    def new_mod(including_mod)
      obj = Type::Instance.new(obj) if obj.is_a?(Type::Class)
      name = obj.screen_name(@scratch)
      @mods[name] ||= Module.new(name, kind)
    end

    def compile(include_relations, ivar_write, cvar_write, class_defs)
      include_relations.each do |including_mod, included_mods|
        new_mod(including_mod).add_includes(included_mods)
      end
      ivar_write.each do |(recv, var), ty|
        var = "self.#{ var }" if recv.is_a?(Type::Class)
        new_mod(recv).add_ivar(var, ty)
      end
      cvar_write.each do |(klass, var), ty|
        new_mod(klass).add_cvar(var, ty)
      end
      class_defs.each_value do |class_def|
        class_def.methods.each do |(singleton, mid), mdefs|
          mdefs.each do |mdef|
            ctxs = @iseq_method_calls[mdef]
            next unless ctxs

            ctxs.each do |ctx|
              next if mid != ctx.mid
              fargs = @sig_fargs[ctx]
              ret_tys = @sig_ret[ctx]

              entry = show_class_or_module(Type::Instance.new(ctx.cref.klass), classes)

              method_name = ctx.mid
              method_name = "self.#{ method_name }" if singleton

              fargs = fargs.screen_name(@scratch)
              if @yields[ctx]
                fargs << show_block(ctx)
              end

              entry[:methods][method_name] ||= []
              entry[:methods][method_name] << show_signature(fargs, ret_tys)

              #stat_classes[recv] = true
              #stat_methods[[recv, method_name]] = true
            end
          end
        end
      end

    end
  end

  class RubySignatureExporter
    def initialize(
      scratch,
      include_relations,
      class_defs, iseq_method_calls, sig_fargs, sig_ret, yields
    )
      @scratch = scratch
      @class_defs = class_defs
      @iseq_method_calls = iseq_method_calls
      @sig_fargs = sig_fargs
      @sig_ret = sig_ret
      @yields = yields
      @include_relations = include_relations
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

    def show_class_or_module(obj, classes)
      obj = Type::Instance.new(obj) if obj.is_a?(Type::Class)
      kind = obj.klass.kind
      name = obj.screen_name(@scratch)
      classes[name] ||= { kind: kind, includes: [], ivars: {}, cvars: {}, methods: {} }
    end

    def show(stat_eps)
      stat_classes = {}
      stat_methods = {}
      classes = {}
      @class_defs.each_value do |class_def|
        included_mods = class_def.modules[false].filter_map do |visible, mod_def|
          Type::Instance.new(mod_def.klass_obj).screen_name(@scratch) if visible
        end
        unless included_mods.empty?
          entry = show_class_or_module(class_def.klass_obj, classes)
          entry[:includes].concat(included_mods)
        end

        ivars = class_def.ivars.write
        unless ivars.empty?
          entry = show_class_or_module(class_def.klass_obj, classes)
          ivars.each do |(singleton, var), ty|
            var = "self.#{ var }" if singleton
            entry[:ivars][var] = ty.screen_name(@scratch)
          end
        end

        cvars = class_def.cvars.write
        unless cvars.empty?
          entry = show_class_or_module(class_def.klass_obj, classes)
          cvars.each do |var, ty|
            entry[:cvars][var] = ty.screen_name(@scratch)
          end
        end

        class_def.methods.each do |(singleton, mid), mdefs|
          mdefs.each do |mdef|
            ctxs = @iseq_method_calls[mdef]
            next unless ctxs

            ctxs.each do |ctx|
              next if mid != ctx.mid
              fargs = @sig_fargs[ctx]
              ret_tys = @sig_ret[ctx]

              entry = show_class_or_module(Type::Instance.new(ctx.cref.klass), classes)

              method_name = ctx.mid
              method_name = "self.#{ method_name }" if singleton

              fargs = fargs.screen_name(@scratch)
              if @yields[ctx]
                fargs << show_block(ctx)
              end

              entry[:methods][method_name] ||= []
              entry[:methods][method_name] << show_signature(fargs, ret_tys)

              #stat_classes[recv] = true
              #stat_methods[[recv, method_name]] = true
            end
          end
        end
      end

      puts "# Classes" # and Modules
      first = true
      classes.each do |recv, cls|
        puts unless first
        first = false
        puts "#{ cls[:kind] } #{ recv }"
        cls[:includes].sort.each do |tys|
          puts "  include #{ tys }"
        end
        cls[:ivars].each do |var, tys|
          puts "  #{ var } : #{ tys }"
        end
        cls[:cvars].each do |var, tys|
          puts "  #{ var } : #{ tys }"
        end
        cls[:methods].each do |method_name, sigs|
          sigs = sigs.sort.join("\n" + " " * (method_name.size + 3) + "| ")
          puts "  def #{ method_name } : #{ sigs }"
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
