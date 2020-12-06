module TypeProf
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

    def show_message(terminated, output)
      if terminated
        output.puts "# CAUTION: Type profiling was terminated prematurely because of the limitation"
        output.puts
      end
    end

    def show_error(errors, backward_edge, output)
      return if errors.empty?
      return unless Config.options[:show_errors]

      output.puts "# Errors"
      errors.each do |ep, msg|
        if ENV["TP_DETAIL"]
          backtrace = filter_backtrace(generate_analysis_trace(ep, {}, backward_edge))
        else
          backtrace = [ep]
        end
        loc, *backtrace = backtrace.map do |ep|
          ep&.source_location
        end
        output.puts "#{ loc }: #{ msg }"
        backtrace.each do |loc|
          output.puts "        from #{ loc }"
        end
      end
      output.puts
    end

    def show_reveal_types(scratch, reveal_types, output)
      return if reveal_types.empty?

      output.puts "# Revealed types"
      reveal_types.each do |source_location, ty|
        output.puts "#  #{ source_location } #=> #{ ty.screen_name(scratch) }"
      end
      output.puts
    end

    def show_gvars(scratch, gvars, output)
      # A signature for global variables is not supported in RBS
      return if gvars.dump.empty?

      output.puts "# Global variables"
      gvars.dump.each do |gvar_name, entry|
        next if entry.type == Type.bot
        s = entry.rbs_declared ? "#" : ""
        output.puts s + "#{ gvar_name }: #{ entry.type.screen_name(scratch) }"
      end
      output.puts
    end
  end

  class RubySignatureExporter
    def initialize(
      scratch,
      class_defs, iseq_method_to_ctxs
    )
      @scratch = scratch
      @class_defs = class_defs
      @iseq_method_to_ctxs = iseq_method_to_ctxs
    end

    def conv_class(namespace, class_def, inner_classes)
      @scratch.namespace = namespace

      if class_def.klass_obj.superclass != :__root__ && class_def.klass_obj.superclass
        omit = class_def.klass_obj.superclass == Type::Builtin[:obj] || class_def.klass_obj == Type::Builtin[:obj]
        superclass = omit ? nil : @scratch.get_class_name(class_def.klass_obj.superclass)
      end

      @scratch.namespace = class_def.name

      consts = {}
      class_def.consts.each do |name, (ty, absolute_path)|
        next if ty.is_a?(Type::Class)
        next if !absolute_path || Config.check_dir_filter(absolute_path) == :exclude
        consts[name] = ty.screen_name(@scratch)
      end

      included_mods = class_def.modules[false].filter_map do |mod_def, _type_args, absolute_paths|
        next if absolute_paths.all? {|path| !path || Config.check_dir_filter(path) == :exclude }
        Type::Instance.new(mod_def.klass_obj).screen_name(@scratch)
      end

      extended_mods = class_def.modules[true].filter_map do |mod_def, _type_args, absolute_paths|
        next if absolute_paths.all? {|path| !path || Config.check_dir_filter(path) == :exclude }
        Type::Instance.new(mod_def.klass_obj).screen_name(@scratch)
      end

      explicit_methods = {}
      iseq_methods = {}
      attr_methods = {}
      ivars = class_def.ivars.dump
      cvars = class_def.cvars.dump

      class_def.methods.each do |(singleton, mid), mdefs|
        mdefs.each do |mdef|
          case mdef
          when ISeqMethodDef
            ctxs = @iseq_method_to_ctxs[mdef]
            next unless ctxs

            ctxs.each do |ctx|
              next if mid != ctx.mid
              next if Config.check_dir_filter(ctx.iseq.absolute_path) == :exclude

              method_name = ctx.mid
              method_name = "self.#{ method_name }" if singleton

              iseq_methods[method_name] ||= [true, []]
              iseq_methods[method_name][0] &&= mdef.pub_meth
              iseq_methods[method_name][1] << @scratch.show_method_signature(ctx)
            end
          when AttrMethodDef
            next if !mdef.absolute_path || Config.check_dir_filter(mdef.absolute_path) == :exclude
            mid = mid.to_s[0..-2].to_sym if mid.to_s.end_with?("=")
            method_name = mid
            method_name = "self.#{ mid }" if singleton
            method_name = [method_name, :"@#{ mid }" != mdef.ivar]
            if attr_methods[method_name]
              if attr_methods[method_name][0] != mdef.kind
                attr_methods[method_name][0] = :accessor
              end
            else
              entry = ivars[[singleton, mdef.ivar]]
              ty = entry ? entry.type : Type.any
              attr_methods[method_name] = [mdef.kind, ty.screen_name(@scratch)]
            end
          when TypedMethodDef
            if mdef.rbs_source
              method_name, sigs = mdef.rbs_source
              explicit_methods[method_name] = sigs
            end
          end
        end
      end

      ivars = ivars.map do |(singleton, var), entry|
        next if entry.absolute_paths.all? {|path| Config.check_dir_filter(path) == :exclude }
        ty = entry.type
        next unless var.to_s.start_with?("@")
        var = "self.#{ var }" if singleton
        next if attr_methods[[singleton ? "self.#{ var.to_s[1..] }" : var.to_s[1..].to_sym, false]]
        next if entry.rbs_declared
        [var, ty.screen_name(@scratch)]
      end.compact

      cvars = cvars.map do |var, entry|
        next if entry.absolute_paths.all? {|path| Config.check_dir_filter(path) == :exclude }
        next if entry.rbs_declared
        [var, entry.type.screen_name(@scratch)]
      end.compact

      if !class_def.absolute_path || Config.check_dir_filter(class_def.absolute_path) == :exclude
        return nil if consts.empty? && included_mods.empty? && extended_mods.empty? && ivars.empty? && cvars.empty? && iseq_methods.empty? && attr_methods.empty? && inner_classes.empty?
      end

      @scratch.namespace = nil

      ClassData.new(
        kind: class_def.kind,
        name: class_def.name,
        superclass: superclass,
        consts: consts,
        included_mods: included_mods,
        extended_mods: extended_mods,
        ivars: ivars,
        cvars: cvars,
        attr_methods: attr_methods,
        explicit_methods: explicit_methods,
        iseq_methods: iseq_methods,
        inner_classes: inner_classes,
      )
    end

    ClassData = Struct.new(:kind, :name, :superclass, :consts, :included_mods, :extended_mods, :ivars, :cvars, :attr_methods, :explicit_methods, :iseq_methods, :inner_classes, keyword_init: true)

    def show(stat_eps, output)
      # make the class hierarchy
      root = {}
      @class_defs.each_value do |class_def|
        h = root
        class_def.name.each do |name|
          h = h[name] ||= {}
        end
        h[:class_def] = class_def
      end

      hierarchy = build_class_hierarchy([], root)

      output.puts "# Classes" # and Modules

      show_class_hierarchy(0, hierarchy, output, true)

      if ENV["TP_STAT"]
        output.puts ""
        output.puts "# TypeProf statistics:"
        output.puts "#   %d execution points" % stat_eps.size
      end

      if ENV["TP_COVERAGE"]
        coverage = {}
        stat_eps.each do |ep|
          path = ep.ctx.iseq.path
          lineno = ep.ctx.iseq.linenos[ep.pc] - 1
          (coverage[path] ||= [])[lineno] ||= 0
          (coverage[path] ||= [])[lineno] += 1
        end
        File.binwrite("typeprof-analysis-coverage.dump", Marshal.dump(coverage))
      end
    end

    def build_class_hierarchy(namespace, hierarchy)
      hierarchy.map do |name, h|
        class_def = h.delete(:class_def)
        class_data = conv_class(namespace, class_def, build_class_hierarchy(namespace + [name], h))
        class_data
      end.compact
    end

    def show_class_hierarchy(depth, hierarchy, output, first)
      hierarchy.each do |class_data|
        output.puts unless first
        first = false

        show_class_data(depth, class_data, output)
      end
    end

    def show_const(namespace, path)
      return path.last.to_s if namespace == path
      i = 0
      i += 1 while namespace[i] && namespace[i] == path[i]
      path[i..].join("::")
    end

    def show_class_data(depth, class_data, output)
      indent = "  " * depth
      name = class_data.name.last
      superclass = " < " + class_data.superclass if class_data.superclass
      output.puts indent + "#{ class_data.kind } #{ name }#{ superclass }"
      first = true
      class_data.consts.each do |name, ty|
        output.puts indent + "  #{ name }: #{ ty }"
        first = false
      end
      class_data.included_mods.sort.each do |mod|
        output.puts indent + "  include #{ mod }"
        first = false
      end
      class_data.extended_mods.sort.each do |mod|
        output.puts indent + "  extend #{ mod }"
        first = false
      end
      class_data.ivars.each do |var, ty|
        output.puts indent + "  #{ var }: #{ ty }" unless var.start_with?("_")
        first = false
      end
      class_data.cvars.each do |var, ty|
        output.puts indent + "  #{ var }: #{ ty }"
        first = false
      end
      class_data.attr_methods.each do |(method_name, hidden), (kind, ty)|
        output.puts indent + "  attr_#{ kind } #{ method_name }#{ hidden ? "()" : "" }: #{ ty }"
        first = false
      end
      class_data.explicit_methods.each do |method_name, sigs|
        sigs = sigs.sort.join("\n" + indent + "#" + " " * (method_name.size + 6) + "| ")
        output.puts indent + "# def #{ method_name }: #{ sigs }"
        first = false
      end
      prev_pub_meth = true
      class_data.iseq_methods.each do |method_name, (pub_meth, sigs)|
        sigs = sigs.sort.join("\n" + indent + " " * (method_name.size + 7) + "| ")
        if prev_pub_meth != pub_meth
          output.puts indent + "  #{ pub_meth ? "public" : "private" }"
          prev_pub_meth = pub_meth
        end
        output.puts indent + "  def #{ method_name }: #{ sigs }"
        first = false
      end
      show_class_hierarchy(depth + 1, class_data.inner_classes, output, first)
      output.puts indent + "end"
    end
  end
end
