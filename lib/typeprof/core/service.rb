module TypeProf::Core
  class Service
    def initialize(options)
      @options = options

      @rb_text_nodes = {}
      @rbs_text_nodes = {}

      @genv = GlobalEnv.new
      @genv.load_core_rbs(load_rbs_declarations(@options[:rbs_collection]).declarations)

      Builtin.new(genv).deploy
    end

    def load_rbs_declarations(rbs_collection)
      if rbs_collection
        loader = RBS::EnvironmentLoader.new
        loader.add_collection(rbs_collection)
        RBS::Environment.from_loader(loader)
      else
        return $raw_rbs_env if defined?($raw_rbs_env)
        loader = RBS::EnvironmentLoader.new
        $raw_rbs_env = RBS::Environment.from_loader(loader)
      end
    end

    attr_reader :genv

    def reset!
      @rb_text_nodes.each_value {|node| node.undefine(@genv) }
      @rbs_text_nodes.each_value {|nodes| nodes.each {|n| n.undefine(@genv) } }
      @genv.define_all
      @rb_text_nodes.each_value {|node| node.uninstall(@genv) }
      @rbs_text_nodes.each_value {|nodes| nodes.each {|n| n.uninstall(@genv) } }
      @genv.run_all
      @rb_text_nodes.clear
      @rbs_text_nodes.clear
    end

    def add_workspace(rb_folder, rbs_folder)
      # Analyze RBS files first so that type declarations are available during RB type inference
      all_files = [rb_folder, rbs_folder].flat_map { |folder| Dir.glob(File.expand_path(folder + "/**/*.{rb,rbs}")) }
      rbs_files, rb_files = separate_rbs_and_rb(all_files.uniq)

      rbs_files.each { |path| update_rbs_file(path, nil) }
      rb_files.each { |path| update_rb_file(path, nil) }
    end

    def update_file(path, code)
      if File.extname(path) == ".rbs"
        update_rbs_file(path, code)
      else
        update_rb_file(path, code)
      end
    end

    def update_rb_file(path, code)
      prev_node = @rb_text_nodes[path]

      code = File.read(path) unless code
      node = AST.parse_rb(path, code)
      return false unless node

      node.diff(@rb_text_nodes[path]) if prev_node
      @rb_text_nodes[path] = node

      node.define(@genv)
      prev_node.undefine(@genv) if prev_node
      @genv.define_all

      node.install(@genv)
      prev_node.uninstall(@genv) if prev_node
      @genv.run_all

      # invariant validation
      if prev_node
        live_vtxs = []
        node.get_vertexes(live_vtxs)
        set = Set.empty
        live_vtxs.uniq.each {|vtx| set << vtx }
        live_vtxs = set

        dead_vtxs = []
        prev_node.get_vertexes(dead_vtxs)
        set = Set.empty
        dead_vtxs.uniq.each {|vtx| set << vtx }
        dead_vtxs = set

        live_vtxs.each do |vtx|
          next unless vtx
          raise vtx.inspect if dead_vtxs.include?(vtx)
        end

        global_vtxs = []
        @genv.get_vertexes(global_vtxs)
        set = Set.empty
        global_vtxs.uniq.each {|vtx| set << vtx }
        global_vtxs = set

        global_vtxs.each do |global_vtx|
          next unless global_vtx.is_a?(Vertex)
          raise if dead_vtxs.include?(global_vtx)
          global_vtx.types.each_value do |prev_vtxs|
            prev_vtxs.each do |prev_vtx|
              raise if dead_vtxs.include?(prev_vtx)
            end
          end
          global_vtx.next_vtxs.each do |next_vtx|
            raise "#{ next_vtx }" if dead_vtxs.include?(next_vtx)
          end
        end
      end

      return true
    end

    def update_rbs_file(path, code)
      prev_decls = @rbs_text_nodes[path]

      code = File.read(path) unless code
      begin
        decls = AST.parse_rbs(path, code)
      rescue RBS::ParsingError
        return false
      end

      # TODO: diff
      @rbs_text_nodes[path] = decls

      decls.each {|decl| decl.define(@genv) }
      prev_decls.each {|decl| decl.undefine(@genv) } if prev_decls
      @genv.define_all

      decls.each {|decl| decl.install(@genv) }
      prev_decls.each {|decl| decl.uninstall(@genv) } if prev_decls
      @genv.run_all

      true
    end

    def process_diagnostic_paths(&blk)
      @genv.process_diagnostic_paths(&blk)
    end

    def diagnostics(path, &blk)
      @rb_text_nodes[path]&.each_diagnostic(@genv, &blk)
    end

    def definitions(path, pos)
      defs = []
      @rb_text_nodes[path]&.retrieve_at(pos) do |node|
        node.boxes(:cread) do |box|
          if box.const_read && box.const_read.cdef
            box.const_read.cdef.defs.each do |cdef_node|
              defs << [cdef_node.lenv.path, cdef_node.cname_code_range]
            end
          end
        end
        node.boxes(:mcall) do |box|
          boxes = []
          box.changes.boxes.each do |key, box|
            # ad-hocly handle Class#new calls
            if key[0] == :mcall && key[3] == :initialize # XXX: better condition?
              boxes << box
            end
          end
          boxes << box if boxes.empty?
          boxes.each do |box|
            box.resolve(genv, nil) do |me, _ty, mid, _orig_ty|
              next unless me
              me.decls.each do |mdecl|
                next unless mdecl.node.lenv.path

                code_range =
                  if mdecl.node.respond_to?(:mname_code_range)
                    mdecl.node.mname_code_range(mid)
                  else
                    mdecl.node.code_range
                  end

                defs << [mdecl.node.lenv.path, code_range]
              end
              me.defs.each do |mdef|
                code_range =
                  if mdef.node.respond_to?(:mname_code_range)
                    mdef.node.mname_code_range(mid)
                  else
                    mdef.node.code_range
                  end

                defs << [mdef.node.lenv.path, code_range]
              end
            end
          end
        end
        return defs unless defs.empty?
      end
      return defs
    end

    def type_definitions(path, pos)
      @rb_text_nodes[path]&.retrieve_at(pos) do |node|
        if node.ret
          ty_defs = []
          node.ret.types.map do |ty, _source|
            mod = case ty
                  when Type::Instance, Type::Singleton
                    ty.mod
                  else
                    base = ty.base_type(@genv)
                    base.mod if base.is_a?(Type::Instance)
                  end

            if mod
              mod.module_decls.each do |mdecl|
                decl_path = mdecl.lenv.path
                ty_defs << [decl_path, mdecl.code_range] if decl_path
              end
              mod.module_defs.each do |mdef_node|
                ty_defs << [mdef_node.lenv.path, mdef_node.code_range]
              end
            end
          end
          return ty_defs
        end
      end
      []
    end

    #: (String, TypeProf::CodePosition) -> Array[[String?, TypeProf::CodeRange]]?
    def references(path, pos)
      refs = []
      @rb_text_nodes[path]&.retrieve_at(pos) do |node|
        case node
        when AST::DefNode
          if node.mid_code_range.include?(pos)
            node.boxes(:mdef) do |mdef|
              me = @genv.resolve_method(mdef.cpath, mdef.singleton, mdef.mid)
              if me
                me.method_call_boxes.each do |box|
                  node = box.node
                  refs << [node.lenv.path, node.code_range]
                end
              end
            end
          end
        # TODO: Callsite
        when AST::ConstantReadNode
          if node.cname_code_range.include?(pos)
            node.boxes(:cread) do |cread_box|
              @genv.resolve_const(cread_box.const_read.cpath).read_boxes.each do |box|
                node = box.node
                refs << [node.lenv.path, node.code_range]
              end
            end
          end
        when AST::ConstantWriteNode
          if node.cname_code_range && node.cname_code_range.include?(pos) && node.static_cpath
            @genv.resolve_const(node.static_cpath).read_boxes.each do |box|
              node = box.node
              refs << [node.lenv.path, node.code_range]
            end
          end
        end
      end
      refs = refs.uniq
      return refs.empty? ? nil : refs
    end

    def rename(path, pos)
      mdefs = []
      cdefs = []
      @rb_text_nodes[path]&.retrieve_at(pos) do |node|
        node.boxes(:mcall) do |box|
          box.resolve(genv, nil) do |me, _ty, _mid, _orig_ty|
            next unless me
            me.defs.each do |mdef|
              mdefs << mdef
            end
          end
        end
        node.boxes(:cread) do |box|
          if box.node.cname_code_range.include?(pos)
            box.const_read.cdef.defs.each do |cdef|
              cdefs << cdef
            end
          end
        end
        if node.is_a?(AST::ConstantWriteNode)
          if node.cname_code_range.include?(pos) && node.static_cpath
            genv.resolve_const(node.static_cpath).defs.each do |cdef|
              cdefs << cdef
            end
          end
        end
        if node.is_a?(AST::DefNode) && node.mid_code_range.include?(pos)
          node.boxes(:mdef) do |mdef|
            mdefs << mdef
          end
        end
      end
      targets = []
      mdefs.each do |mdef|
        # TODO: support all method definition nodes rather than defn/defs (e.g., attr_reader, alias, SIG_DEF, etc.)
        targets << [mdef.node.lenv.path, mdef.node.mid_code_range]
        me = @genv.resolve_method(mdef.cpath, mdef.singleton, mdef.mid)
        if me
          me.method_call_boxes.each do |box|
            # TODO: if it is a super node, we need to change its method name too
            targets << [box.node.lenv.path, box.node.mid_code_range]
          end
        end
      end
      cdefs.each do |cdef|
        if cdef.is_a?(AST::ConstantWriteNode)
          targets << [cdef.lenv.path, cdef.cname_code_range] if cdef.cname_code_range
        end
        ve = @genv.resolve_const(cdef.static_cpath)
        ve.read_boxes.each do |box|
          targets << [box.node.lenv.path, box.node.cname_code_range]
        end
      end
      if targets.all? {|_path, cr| cr }
        targets.uniq
      else
        # TODO: report an error
        nil
      end
    end

    def hover(path, pos)
      @rb_text_nodes[path]&.retrieve_at(pos) do |node|
        node.boxes(:mcall) do |box|
          boxes = []
          box.changes.boxes.each do |key, box|
            # ad-hocly handle Class#new calls
            if key[0] == :mcall && key[3] == :initialize # XXX: better condition?
              boxes << box
            end
          end
          boxes << box if boxes.empty?
          boxes.each do |box|
            box.resolve(genv, nil) do |me, ty, mid, orig_ty|
              if me
                if !me.decls.empty?
                  me.decls.each do |mdecl|
                    return "#{ orig_ty.show }##{ mid } : #{ mdecl.show }"
                  end
                end
                if !me.defs.empty?
                  me.defs.each do |mdef|
                    return "#{ orig_ty.show }##{ mid } : #{ mdef.show(@options[:output_parameter_names]) }"
                  end
                end
              end
            end
          end
          return "??? failed to hover"
        end
        return node.ret ? node.ret.show : "??? no type ???"
      end
    end

    def code_lens(path)
      cpaths = []
      @rb_text_nodes[path]&.traverse do |event, node|
        if node.is_a?(AST::ModuleBaseNode)
          if node.static_cpath
            if event == :enter
              cpaths << node.static_cpath
            else
              cpaths.pop
            end
          end
        else
          if event == :enter
            next if node.is_a?(AST::DefNode) && node.rbs_method_type
            node.boxes(:mdef) do |mdef|
              hint = mdef.show(@options[:output_parameter_names])
              if hint
                yield mdef.node.code_range, hint
              end
            end
          end
        end
      end
    end

    def completion(path, trigger, pos)
      @rb_text_nodes[path]&.retrieve_at(pos) do |node|
        if node.code_range.last == pos.right
          node.ret.types.map do |ty, _source|
            base_ty = ty.base_type(genv)

            @genv.each_superclass(base_ty.mod, base_ty.is_a?(Type::Singleton)) do |mod, singleton|
              mod.methods[singleton].each do |mid, me|
                sig = nil
                me.decls.each do |mdecl|
                  sig = mdecl.method_types.map {|method_type| method_type.instance_variable_get(:@raw_node).to_s }.join(" | ")
                  break
                end
                unless sig
                  me.defs.each do |mdef|
                    sig = mdef.show(@options[:output_parameter_names])
                    break
                  end
                end
                yield mid, "#{ mod.cpath.join("::" )}#{ singleton ? "." : "#" }#{ mid } : #{ sig }" if sig
              end
            end
          end
          return
        end
      end
    end

    def format_declared_const_path(cpath, stack)
      scope_cpath =
        stack.reverse_each.find do |entry|
          (entry.is_a?(AST::ClassNode) || entry.is_a?(AST::ModuleNode)) &&
            entry.static_cpath &&
            !entry.static_cpath.empty?
        end&.static_cpath

      return cpath.join("::") unless scope_cpath
      return cpath.join("::") unless cpath[0, scope_cpath.size] == scope_cpath

      rel_cpath = cpath.drop(scope_cpath.size)
      rel_cpath.empty? ? cpath.join("::") : rel_cpath.join("::")
    end

    def dump_declarations(path)
      stack = []
      out = []
      @rb_text_nodes[path]&.traverse do |event, node|
        case node
        when AST::ModuleNode
          if node.static_cpath
            if event == :enter
              out << "  " * stack.size + "module #{ node.static_cpath.join("::") }"
              if stack == [:toplevel]
                out << "end"
                stack.pop
              end
              stack.push(node)
            else
              stack.pop
              out << "  " * stack.size + "end"
            end
          end
        when AST::ClassNode, AST::SingletonClassNode
          if node.static_cpath
            next if stack.any? { node.is_a?(AST::SingletonClassNode) && (_1.is_a?(AST::ClassNode) || _1.is_a?(AST::ModuleNode)) && node.static_cpath == _1.static_cpath }

            if event == :enter
              s = "class #{ node.static_cpath.join("::") }"
              mod = @genv.resolve_cpath(node.static_cpath)
              superclass = mod.superclass
              if superclass == nil
                s << " # failed to identify its superclass"
              elsif superclass.cpath != []
                s << " < #{ superclass.show_cpath }"
              end
              if stack == [:toplevel]
                out << "end"
                stack.pop
              end
              out << "  " * stack.size + s
              stack.push(node)
              mod.included_modules.each do |inc_def, inc_mod|
                if inc_def.is_a?(AST::ConstantReadNode) && inc_def.lenv.path == path
                  out << "  " * stack.size + "include #{ inc_mod.show_cpath }"
                end
              end
            else
              stack.pop
              out << "  " * stack.size + "end"
            end
          end
        when AST::ConstantWriteNode
          if node.static_cpath
            if event == :enter
              out << "  " * stack.size + "#{ format_declared_const_path(node.static_cpath, stack) }: #{ node.ret.show }"
            end
          end
        else
          if event == :enter
            node.boxes(:mdef) do |mdef|
              if stack.empty?
                out << "  " * stack.size + "class Object"
                stack << :toplevel
              end
              if @options[:output_source_locations]
                pos = mdef.node.code_range.first
                out << "  " * stack.size + "# #{ path }:#{ pos.lineno }:#{ pos.column + 1 }"
              end
              out << "  " * stack.size + "def #{ mdef.singleton ? "self." : "" }#{ mdef.mid }: " + mdef.show(@options[:output_parameter_names])
            end
          end
        end
      end
      if stack == [:toplevel]
        out << "end"
        stack.pop
      end
      out.join("\n") + "\n"
    end

    def get_method_sig(cpath, singleton, mid)
      s = []
      @genv.resolve_method(cpath, singleton, mid).defs.each do |mdef|
        s << "def #{ mid }: " + mdef.show
      end
      s
    end

    def batch(files, output)
      if @options[:output_typeprof_version]
        output.puts "# TypeProf #{ TypeProf::VERSION }"
        output.puts
      end

      # Analyze RBS files first so that type declarations are available during RB type inference
      rbs_files, rb_files = separate_rbs_and_rb(files)
      sorted_files = rbs_files + rb_files

      i = 0
      show_files = sorted_files.select do |file|
        if @options[:display_indicator]
          $stderr << "\r[%d/%d] %s\e[K" % [i, sorted_files.size, file]
          i += 1
        end

        res = update_file(file, File.read(file))

        if res
          true
        else
          output.puts "# failed to analyze: #{ file }"
          false
        end
      rescue => e
        output.puts "# error: #{ file }"
        raise e
      end
      if @options[:display_indicator]
        $stderr << "\r\e[K"
      end

      first = true
      show_files.each do |file|
        next if File.extname(file) == ".rbs"
        output.puts unless first
        first = false
        output.puts "# #{ file }"
        if @options[:output_diagnostics]
          diagnostics(file) do |diag|
            output.puts "# #{ diag.code_range.to_s }:#{ diag.msg }"
          end
        end
        output.puts dump_declarations(file)
      end

      if @options[:output_stats]
        rb_files = show_files.reject {|f| File.extname(f) == ".rbs" }
        stats = collect_stats(rb_files)
        output.puts
        output.puts format_stats(stats)
      end
    end

    def collect_stats(files)
      file_stats = []

      files.each do |path|
        methods = []
        constants = []
        seen_ivars = Set.empty
        ivars = []
        seen_cvars = Set.empty
        cvars = []
        seen_gvars = Set.empty
        gvars = []

        @rb_text_nodes[path]&.traverse do |event, node|
          next unless event == :enter

          node.boxes(:mdef) do |mdef|
            param_slots = []
            f = mdef.f_args
            [f.req_positionals, f.opt_positionals, f.post_positionals, f.req_keywords, f.opt_keywords].each do |ary|
              ary.each {|vtx| param_slots << classify_vertex(vtx) }
            end
            [f.rest_positionals, f.rest_keywords].each do |vtx|
              param_slots << classify_vertex(vtx) if vtx
            end

            is_initialize = mdef.mid == :initialize
            ret_slots = is_initialize ? [] : [classify_vertex(mdef.ret)]

            blk = mdef.record_block
            block_param_slots = []
            block_ret_slots = []
            if blk.used
              blk.f_args.each {|vtx| block_param_slots << classify_vertex(vtx) }
              block_ret_slots << classify_vertex(blk.ret)
            end

            methods << {
              mid: mdef.mid,
              singleton: mdef.singleton,
              param_slots: param_slots,
              ret_slots: ret_slots,
              block_param_slots: block_param_slots,
              block_ret_slots: block_ret_slots,
            }
          end

          if node.is_a?(AST::ConstantWriteNode) && node.static_cpath
            constants << classify_vertex(node.ret)
          end

          if node.is_a?(AST::InstanceVariableWriteNode)
            scope = node.lenv.cref.scope_level
            if scope == :class || scope == :instance
              key = [node.lenv.cref.cpath, scope == :class, node.var]
              unless seen_ivars.include?(key)
                seen_ivars << key
                ve = @genv.resolve_ivar(key[0], key[1], key[2])
                ivars << classify_vertex(ve.vtx)
              end
            end
          end

          if node.is_a?(AST::ClassVariableWriteNode)
            key = [node.lenv.cref.cpath, node.var]
            unless seen_cvars.include?(key)
              seen_cvars << key
              ve = @genv.resolve_cvar(key[0], key[1])
              cvars << classify_vertex(ve.vtx)
            end
          end

          if node.is_a?(AST::GlobalVariableWriteNode)
            unless seen_gvars.include?(node.var)
              seen_gvars << node.var
              ve = @genv.resolve_gvar(node.var)
              gvars << classify_vertex(ve.vtx)
            end
          end
        end

        file_stats << {
          path: path,
          methods: methods,
          constants: constants,
          ivars: ivars,
          cvars: cvars,
          gvars: gvars,
        }
      end

      file_stats
    end

    def classify_vertex(vtx)
      vtx.types.empty? ? :untyped : :typed
    end

    def format_stats(stats)
      total_methods = 0
      fully_typed = 0
      partially_typed = 0
      fully_untyped = 0

      slot_categories = %i[param ret blk_param blk_ret const ivar cvar gvar]
      typed = Hash.new(0)
      untyped = Hash.new(0)

      file_summaries = []

      stats.each do |file|
        f_typed = 0
        f_total = 0

        file[:methods].each do |m|
          total_methods += 1

          method_slot_keys = %i[param_slots ret_slots block_param_slots block_ret_slots]
          category_keys = %i[param ret blk_param blk_ret]

          all_slots = method_slot_keys.flat_map {|k| m[k] }

          method_slot_keys.zip(category_keys) do |slot_key, cat|
            m[slot_key].each do |s|
              if s == :typed
                typed[cat] += 1
              else
                untyped[cat] += 1
              end
            end
          end

          if all_slots.empty? || all_slots.all? {|s| s == :typed }
            fully_typed += 1
          elsif all_slots.none? {|s| s == :typed }
            fully_untyped += 1
          else
            partially_typed += 1
          end

          f_typed += all_slots.count(:typed)
          f_total += all_slots.size
        end

        %i[constants ivars cvars gvars].zip(%i[const ivar cvar gvar]) do |data_key, cat|
          file[data_key].each do |s|
            f_total += 1
            if s == :typed
              typed[cat] += 1
              f_typed += 1
            else
              untyped[cat] += 1
            end
          end
        end

        if f_total > 0
          file_summaries << {
            path: file[:path],
            methods: file[:methods].size,
            typed: f_typed,
            total: f_total,
          }
        end
      end

      overall_typed = slot_categories.sum {|c| typed[c] }
      overall_untyped = slot_categories.sum {|c| untyped[c] }
      overall_total = overall_typed + overall_untyped

      labels = {
        param: "Parameter slots",
        ret: "Return slots",
        blk_param: "Block parameter slots",
        blk_ret: "Block return slots",
        const: "Constants",
        ivar: "Instance variables",
        cvar: "Class variables",
        gvar: "Global variables",
      }

      lines = []
      lines << "# TypeProf Evaluation Statistics"
      lines << "#"
      lines << "# Total methods: #{ total_methods }"
      lines << "#   Fully typed:     #{ fully_typed }"
      lines << "#   Partially typed: #{ partially_typed }"
      lines << "#   Fully untyped:   #{ fully_untyped }"

      slot_categories.each do |cat|
        total = typed[cat] + untyped[cat]
        lines << "#"
        lines << "# #{ labels[cat] }: #{ total }"
        lines << "#   Typed:   #{ typed[cat] } (#{ pct(typed[cat], total) })"
        lines << "#   Untyped: #{ untyped[cat] } (#{ pct(untyped[cat], total) })"
      end

      lines << "#"
      lines << "# Overall: #{ overall_typed }/#{ overall_total } typed (#{ pct(overall_typed, overall_total) })"
      lines << "#          #{ overall_untyped }/#{ overall_total } untyped (#{ pct(overall_untyped, overall_total) })"

      if file_summaries.size > 1
        lines << "#"
        lines << "# Per-file breakdown:"
        file_summaries.each do |fs|
          lines << "#   #{ fs[:path] }: #{ fs[:methods] } methods, #{ fs[:typed] }/#{ fs[:total] } typed (#{ pct(fs[:typed], fs[:total]) })"
        end
      end

      lines.join("\n")
    end

    def pct(n, total)
      return "0.0%" if total == 0
      "#{ (n * 100.0 / total).round(1) }%"
    end

    private

    def separate_rbs_and_rb(files)
      files
        .reject { |file| exclude_files.include?(File.expand_path(file)) }
        .partition { |file| File.extname(file) == ".rbs" }
    end

    def exclude_files
      @exclude_files ||= (@options[:exclude_patterns] || []).each_with_object(::Set.new) { |pattern, set|
        Dir.glob(File.expand_path(pattern)) { |path| set << path }
      }
    end
  end
end

if $0 == __FILE__
  core = TypeProf::Core::Service.new({})
  core.add_workspaces(["foo"].to_a)
  core.update_rb_file("foo", "foo")
end
