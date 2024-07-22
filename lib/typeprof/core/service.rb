module TypeProf::Core
  class Service
    def initialize
      unless defined?($rbs_env)
        loader = RBS::EnvironmentLoader.new
        $rbs_env = RBS::Environment.from_loader(loader)
      end

      @text_nodes = {}

      @genv = GlobalEnv.new
      @genv.load_core_rbs($rbs_env.declarations)

      Builtin.new(genv).deploy
    end

    attr_reader :genv

    def reset!
      @text_nodes.each_value do |node|
        if node.is_a?(Array)
          node.each {|n| n.undefine(@genv) }
        else
          node.undefine(@genv)
        end
      end
      @genv.define_all
      @text_nodes.each_value do |node|
        if node.is_a?(Array)
          node.each {|n| n.uninstall(@genv) }
        else
          node.uninstall(@genv)
        end
      end
      @genv.run_all
      @text_nodes.clear
    end

    def add_workspace(rb_folder, rbs_folder)
      Dir.glob(File.expand_path(rb_folder + "/**/*.rb")) do |path|
        update_rb_file(path, nil)
      end
      Dir.glob(File.expand_path(rbs_folder + "/**/*.rbs")) do |path|
        update_rbs_file(path, nil)
      end
    end

    def update_rb_file(path, code)
      prev_node = @text_nodes[path]

      code = File.read(path) unless code
      node = AST.parse_rb(path, code)
      return unless node

      node.diff(@text_nodes[path]) if prev_node
      @text_nodes[path] = node

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
        set = Set[]
        live_vtxs.uniq.each {|vtx| set << vtx }
        live_vtxs = set

        dead_vtxs = []
        prev_node.get_vertexes(dead_vtxs)
        set = Set[]
        dead_vtxs.uniq.each {|vtx| set << vtx }
        dead_vtxs = set

        live_vtxs.each do |vtx|
          next unless vtx
          raise vtx.inspect if dead_vtxs.include?(vtx)
        end

        global_vtxs = []
        @genv.get_vertexes(global_vtxs)
        set = Set[]
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
    end

    def update_rbs_file(path, code)
      prev_decls = @text_nodes[path]

      code = File.read(path) unless code
      begin
        decls = AST.parse_rbs(path, code)
      rescue SyntaxError
        return
      end

      # TODO: diff
      @text_nodes[path] = decls

      decls.each {|decl| decl.define(@genv) }
      prev_decls.each {|decl| decl.undefine(@genv) } if prev_decls
      @genv.define_all

      decls.each {|decl| decl.install(@genv) }
      prev_decls.each {|decl| decl.uninstall(@genv) } if prev_decls
      @genv.run_all
    end

    def diagnostics(path, &blk)
      node = @text_nodes[path]
      node.diagnostics(@genv, &blk) if node
    end

    def definitions(path, pos)
      defs = []
      @text_nodes[path].retrieve_at(pos) do |node|
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
      @text_nodes[path].retrieve_at(pos) do |node|
        if node.ret
          ty_defs = []
          node.ret.types.map do |ty, _source|
            if ty.is_a?(Type::Instance)
              ty.mod.module_decls.each do |mdecl|
                # TODO
              end
              ty.mod.module_defs.each do |mdef_node|
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
      @text_nodes[path].retrieve_at(pos) do |node|
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
      @text_nodes[path].retrieve_at(pos) do |node|
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
      @text_nodes[path].retrieve_at(pos) do |node|
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
                    return "#{ orig_ty.show }##{ mid } : #{ mdef.show }"
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
      @text_nodes[path].traverse do |event, node|
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
              hint = mdef.show
              if hint
                yield mdef.node.code_range, hint
              end
            end
          end
        end
      end
    end

    def completion(path, trigger, pos)
      @text_nodes[path].retrieve_at(pos) do |node|
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
                    sig = mdef.show
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

    def dump_declarations(path)
      depth = 0
      out = []
      @text_nodes[path].traverse do |event, node|
        case node
        when AST::ModuleNode
          if node.static_cpath
            if event == :enter
              out << "  " * depth + "module #{ node.static_cpath.join("::") }"
              depth += 1
            else
              depth -= 1
              out << "  " * depth + "end"
            end
          end
        when AST::ClassNode
          if node.static_cpath
            if event == :enter
              s = "class #{ node.static_cpath.join("::") }"
              mod = @genv.resolve_cpath(node.static_cpath)
              superclass = mod.superclass
              if superclass == nil
                s << " # failed to identify its superclass"
              elsif superclass.cpath != []
                s << " < #{ superclass.show_cpath }"
              end
              out << "  " * depth + s
              depth += 1
              mod.included_modules.each do |inc_def, inc_mod|
                if (inc_def.is_a?(AST::ConstantReadNode) || inc_def.is_a?(AST::ConstantPathNode)) && inc_def.lenv.path == path
                  out << "  " * depth + "include #{ inc_mod.show_cpath }"
                end
              end
            else
              depth -= 1
              out << "  " * depth + "end"
            end
          end
        when AST::ConstantWriteNode
          if node.static_cpath
            if event == :enter
              out << "  " * depth + "#{ node.static_cpath.join("::") }: #{ node.ret.show }"
            end
          end
        else
          if event == :enter
            node.boxes(:mdef) do |mdef|
              out << "  " * depth + "def #{ mdef.singleton ? "self." : "" }#{ mdef.mid }: " + mdef.show
            end
          end
        end
      end
      out = out.map {|s| s + "\n" }.chunk {|s| s.start_with?("def ") }.flat_map do |toplevel, lines|
        if toplevel
          ["class Object\n"] + lines.map {|line| "  " + line } + ["end\n"]
        else
          lines
        end
      end
      out.join
    end

    def get_method_sig(cpath, singleton, mid)
      s = []
      @genv.resolve_method(cpath, singleton, mid).defs.each do |mdef|
        s << "def #{ mid }: " + mdef.show
      end
      s
    end
  end
end

if $0 == __FILE__
  core = TypeProf::Core::Service.new
  core.add_workspaces(["foo"].to_a)
  core.update_rb_file("foo", "foo")
end
