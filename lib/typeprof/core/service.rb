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
      unless defined?($rbs_builder)
        loader = RBS::EnvironmentLoader.new
        rbs_env = RBS::Environment.from_loader(loader).resolve_type_names
        $rbs_builder = RBS::DefinitionBuilder.new(env: rbs_env)
      end

      @genv = GlobalEnv.new($rbs_builder)
      Signatures.build(genv)
      Builtin.new(genv).deploy

      @text_nodes = {}
    end

    attr_reader :genv

    def add_workspaces(folders, &blk)
      folders.each do |folder|
        Dir.glob(File.expand_path(folder + "/**/*.rb")) do |path|
          update_file(path, nil) if !blk || blk.call(path)
        end
      end
    end

    def update_file(path, code)
      prev_node = @text_nodes[path]

      code = File.read(path) unless code
      begin
        node = AST.parse(path, code)
      rescue SyntaxError
        return
      end

      node.diff(@text_nodes[path]) if prev_node
      @text_nodes[path] = node

      node.define(@genv)
      if prev_node
        prev_node.undefine(@genv)
      end
      @genv.define_all

      node.install(@genv)
      prev_node.uninstall(@genv) if prev_node
      @genv.run_all

      # OR:
      # node.install(@genv)
      # @genv.run_all
      # if prev_node
      #   prev_node.uninstall(@genv)
      #   @genv.run_all
      # end

      # invariant validation
      if prev_node
        live_vtxs = Set[]
        live_boxes = Set[]
        node.get_vertexes_and_boxes(live_vtxs, live_boxes)

        dead_vtxs = Set[]
        dead_boxes = Set[]
        prev_node.get_vertexes_and_boxes(dead_vtxs, dead_boxes)

        #dump_graph(path)
        live_vtxs.each do |vtx|
          raise if dead_vtxs.include?(vtx)
        end

        global_vtxs = Set[]
        @genv.get_vertexes_and_boxes(global_vtxs)

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
      if @text_nodes[path]
        @text_nodes[path].diagnostics(@genv, &blk)
      end
    end

    def definitions(path, pos)
      defs = []
      @text_nodes[path].hover(pos) do |node|
        site = node.sites[:class_new] || node.sites[:main]
        if site.is_a?(CallSite)
          site.resolve(genv) do |_ty, mid, me, _param_map|
            next unless me
            me.defs.each do |mdef|
              defs << [mdef.node.lenv.path, mdef.node.code_range]
            end
          end
        end
        return defs
      end
    end

    def hover(path, pos)
      @text_nodes[path].hover(pos) do |node|
        _key, site = node.sites.find {|key, site| key.is_a?(Array) && key[0] == :class_new }
        site ||= node.sites[:main]
        if site.is_a?(CallSite)
          site.resolve(genv) do |ty, mid, me, _param_map|
            if me && !me.defs.empty?
              me.defs.each do |mdef|
                return "#{ ty.show }##{ mid } : #{ mdef.show }"
              end
            end
          end
          return "???"
        else
          return node.ret.show
        end
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
          if event == :enter && !node.method_defs.empty?
            node.method_defs.each do |cpath, singleton, mid, mdef|
              #puts " " * depth + "# #{ d.node.code_range }"
              hint = "def #{ mid }: " + mdef.show
              if hint
                pos = mdef.node.code_range.first
                yield TypeProf::CodeRange.new(pos, pos.right), hint
              end
            end
          end
        end
      end
    end

    def completion(path, trigger, pos)
      @text_nodes[path].hover(pos) do |node|
        if node.code_range.last == pos.right
          node.ret.types.map do |ty, _source|
            ty.base_types(genv).each do |base_ty|
              dir = genv.resolve_cpath(base_ty.cpath)
              singleton = base_ty.is_a?(Type::Module)
              while true
                dir.methods[singleton].each do |mid, me|
                  sig = nil
                  me.decls.each do |mdecl|
                    sig = mdecl.rbs_member.overloads.map {|overload| overload.method_type.to_s }.join(" | ")
                    break
                  end
                  unless sig
                    me.defs.each do |mdef|
                      sig = mdef.show
                      break
                    end
                  end
                  yield mid, "#{ dir.cpath.join("::" )}#{ singleton ? "." : "#" }#{ mid } : #{ sig }"
                end
                # TODO: support aliases
                # TODO: support include module
                dir, singleton = genv.get_superclass(dir, singleton)
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
              superclass = @genv.resolve_cpath(node.static_cpath).superclass
              if superclass == nil
                s << " # failed to identify its superclass"
              elsif superclass.cpath != []
                s << " < #{ superclass.cpath.join("::") }"
              end
              out << "  " * depth + s
              depth += 1
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
          if event == :enter && !node.method_defs.empty?
            node.method_defs.each do |cpath, singleton, mid, mdef|
              out << "  " * depth + "def #{ singleton ? "self." : "" }#{ mid }: " + mdef.show
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
      @genv.resolve_meth(cpath, singleton, mid).defs.each do |mdef|
        s << "def #{ mid }: " + mdef.show
      end
      s
    end
  end
end

if $0 == __FILE__
  core = TypeProf::Core::Service.new
  core.add_workspaces(["foo"].to_a)
  core.update_file("foo", "foo")
end