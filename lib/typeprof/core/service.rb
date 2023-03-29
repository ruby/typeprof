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
      @genv.run_all

      if prev_node
        prev_node.uninstall(@genv)
        @genv.run_all
      end

      # OR:
      # node.install(@genv)
      # prev_node.uninstall(@genv) if prev_node
      # @genv.run_all

      # invariant validation
      if prev_node
        dead_vtxs = Set[]
        dead_boxes = Set[]
        prev_node.get_vertexes_and_boxes(dead_vtxs, dead_boxes)

        live_vtxs = Set[]
        live_boxes = Set[]
        @text_nodes.each do |path_, node|
          node.get_vertexes_and_boxes(live_vtxs, live_boxes)
        end

        if live_vtxs.to_a & dead_vtxs.to_a != []
          dump_graph(path)
          raise (live_vtxs.to_a & dead_vtxs.to_a).to_s
        end

        if live_boxes.to_a & dead_boxes.to_a != []
          raise
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
        when ConstReadSite
          puts "\e[32m#{ box.long_inspect }\e[m"
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
          site.resolve(genv) do |_ty, mds|
            next unless mds
            mds.each do |md|
              case md
              when MethodDecl
              when MethodDef
                defs << [md.node.lenv.path, md.node.code_range]
              end
            end
          end
        end
        return defs
      end
    end

    def hover(path, pos)
      @text_nodes[path].hover(pos) do |node|
        site = node.sites[:class_new] || node.sites[:main]
        if site.is_a?(CallSite)
          site.resolve(genv) do |_ty, mds|
            next unless mds
            mds.each do |md|
              case md
              when MethodDecl
              when MethodDef
                return "def #{ md.singleton ? "self." : "" }#{ md.mid }: " + md.show
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
          if event == :enter && !node.defs.empty?
            node.defs.each do |d|
              case d
              when MethodDef
                #puts " " * depth + "# #{ d.node.code_range }"
                hint = "def #{ d.mid }: " + d.show
              when ConstDef
                hint = "#{ d.cpath.join("::") }::#{ d.cname }: " + d.val.show
              end
              if hint
                pos = d.node.code_range.first
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
              genv.enumerate_methods(base_ty.cpath, base_ty.is_a?(Type::Module)) do |cpath, singleton, mdefs|
                mdefs.each do |mid, entity|
                  sig = nil
                  entity.decls.each do |mdecl|
                    sig = mdecl.rbs_member.overloads.map {|overload| overload.method_type.to_s }.join(" | ")
                    break
                  end
                  unless sig
                    entity.defs.each do |mdef|
                      sig = mdef.show
                      break
                    end
                  end
                  yield mid, "#{ cpath.join("::" )}#{ singleton ? "." : "#" }#{ mid } : #{ sig }"
                end
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
              superclass_cpath = @genv.resolve_cpath(node.static_cpath).superclass_cpath
              if superclass_cpath == nil
                s << " # failed to identify its superclass"
              elsif superclass_cpath != []
                s << " < #{ superclass_cpath.join("::") }"
              end
              out << "  " * depth + s
              depth += 1
            else
              depth -= 1
              out << "  " * depth + "end"
            end
          end
        else
          if event == :enter && !node.defs.empty?
            node.defs.each do |d|
              case d
              when MethodDef
                out << "  " * depth + "def #{ d.singleton ? "self." : "" }#{ d.mid }: " + d.show
              when ConstDef
                out << "  " * depth + "#{ d.cpath.join("::") }::#{ d.cname }: " + d.val.show
              end
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
      @genv.get_method_entity(MethodEntry.new(cpath, singleton, mid)).defs.each do |mdef|
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