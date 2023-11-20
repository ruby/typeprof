module TypeProf::Core
  class TextId
    def initialize(path, version)
      @path = path
      @version = version
    end

    attr_reader :path, :version

    def ==(other)
      @path == other.path && @version == other.version
    end

    alias eql? ==

    def to_s
      "#{ @path }@#{ @version }"
    end
  end

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

    def add_workspaces(folders, &blk)
      folders.each do |folder|
        Dir.glob(File.expand_path(folder + "/**/*.{rb,rbs}")) do |path|
          next if blk && !blk.call(path)
          if File.extname(path) == ".rb"
            update_rb_file(path, nil)
          else
            update_rbs_file(path, nil)
          end
        end
        # TODO: *.rbs
      end
    end

    def update_rb_file(path, code)
      prev_node = @text_nodes[path]

      code = File.read(path) unless code
      begin
        node = AST.parse_rb(path, code)
      rescue SyntaxError
        return
      end

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

        #dump_graph(path)
        live_vtxs.each do |vtx|
          next unless vtx
          raise if dead_vtxs.include?(vtx)
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

    def dump_graph(path)
      node = @text_nodes[path]

      vtxs = Set[]
      puts node.dump(vtxs)
      vtxs = Set[]
      boxes = Set[]
      node.get_vertexes_and_boxes(vtxs, boxes)
      puts "---"
      vtxs.each do |vtx|
        case vtx
        when Vertex
          puts "\e[34m#{ vtx.long_inspect }\e[m: #{ vtx.show }"
          vtx.next_vtxs.each do |nvtx|
            puts "  #{ vtx } -> #{ nvtx }"
          end
        end
      end
      boxes.each do |box|
        case box
        when CallSite
          puts "\e[33m#{ box.long_inspect }\e[m"
          puts "  recv: #{ box.recv }"
          puts "  args: (#{ box.a_args.join(", ") })"
          puts "  ret: #{ box.ret }"
        end
      end
      boxes.each do |box|
        case box
        when IVarReadSite
          puts "\e[32m#{ box.long_inspect }\e[m"
          puts "  ret: #{ box.ret }"
        end
      end
    end

    def diagnostics(path, &blk)
      node = @text_nodes[path]
      node.diagnostics(@genv, &blk) if node
    end

    def definitions(path, pos)
      defs = []
      @text_nodes[path].hover(pos) do |node|
        sites = node.sites[:class_new] || node.sites[:main]
        next unless sites
        sites.each do |site|
          case site
          when ConstReadSite
            if site.const_read && site.const_read.cdef
              site.const_read.cdef.defs.each do |cdef_node|
                defs << [cdef_node.lenv.path, cdef_node.code_range]
              end
            end
          when CallSite
            site.resolve(genv, nil) do |_ty, mid, me, _param_map|
              next unless me
              me.defs.each do |mdef|
                defs << [mdef.node.lenv.path, mdef.node.code_range]
              end
            end
          end
        end
      end
      return defs
    end

    def references(path, pos)
      refs = []
      @text_nodes[path].hover(pos) do |node|
        if node.is_a?(AST::DEFN) && node.sites[:mdef]
          mdefs = node.sites[:mdef]
          mdefs.each do |mdef|
            me = @genv.resolve_method(mdef.cpath, mdef.singleton, mdef.mid)
            if me
              me.callsites.each do |callsite|
                node = callsite.node
                refs << [node.lenv.path, node.code_range]
              end
            end
          end
        end
      end
      refs = refs.uniq
      return refs.empty? ? nil : refs
    end

    def rename(path, pos)
      mdefs = []
      @text_nodes[path].hover(pos) do |node|
        sites = node.sites[:main]
        if sites
          sites.each do |site|
            if site.is_a?(CallSite)
              site.resolve(genv, nil) do |_ty, mid, me, _param_map|
                next unless me
                me.defs.each do |mdef|
                  mdefs << mdef
                end
              end
            end
          end
        elsif node.is_a?(AST::DEFN) && node.sites[:mdef]
          node.sites[:mdef].each do |mdef|
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
          me.callsites.each do |callsite|
            # TODO: if it is a super node, we need to change its method name too
            targets << [callsite.node.lenv.path, callsite.node.mid_code_range]
          end
        end
      end
      if targets.all? {|_path, cr| cr }
        targets
      else
        # TODO: report an error
        nil
      end
    end

    def hover(path, pos)
      @text_nodes[path].hover(pos) do |node|
        sites = node.sites[:class_new] || node.sites[:main]
        if sites
          sites.each do |site|
            if site.is_a?(CallSite)
              site.resolve(genv, nil) do |ty, mid, me, _param_map|
                if me
                  if !me.decls.empty?
                    me.decls.each do |mdecl|
                      return "#{ ty.show }##{ mid } : #{ mdecl.show }"
                    end
                  end
                  if !me.defs.empty?
                    me.defs.each do |mdef|
                      return "#{ ty.show }##{ mid } : #{ mdef.show }"
                    end
                  end
                end
              end
              return "??? failed to hover"
            end
          end
        end
        return node.ret ? node.ret.show : "??? no type ???"
      end
    end

    def code_lens(path)
      cpaths = []
      @text_nodes[path].traverse do |event, node|
        case node
        when AST::MODULE, AST::CLASS
          if node.static_cpath
            if event == :enter
              cpaths << node.static_cpath
            else
              cpaths.pop
            end
          end
        else
          if event == :enter && node.sites[:mdef] && !node.sites[:mdef].empty?
            next if node.is_a?(AST::DefNode) && node.rbs_method_type
            node.sites[:mdef].each do |mdef|
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
            mod = base_ty.mod
            singleton = base_ty.is_a?(Type::Singleton)
            while mod
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
              # TODO: support aliases
              # TODO: support include module
              mod, singleton = genv.get_superclass(mod, singleton)
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
        when AST::MODULE
          if node.static_cpath
            if event == :enter
              out << "  " * depth + "module #{ node.static_cpath.join("::") }"
              depth += 1
            else
              depth -= 1
              out << "  " * depth + "end"
            end
          end
        when AST::CLASS
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
              mod.included_modules.each_value do |inc_mod|
                out << "  " * depth + "include #{ inc_mod.show_cpath }"
              end
            else
              depth -= 1
              out << "  " * depth + "end"
            end
          end
        when AST::CDECL
          if node.static_cpath
            if event == :enter
              out << "  " * depth + "#{ node.static_cpath.join("::") }: #{ node.ret.show }"
            end
          end
        else
          if event == :enter && node.sites[:mdef] && !node.sites[:mdef].empty?
            node.sites[:mdef].each do |mdef|
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