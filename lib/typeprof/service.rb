module TypeProf
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
      @genv = GlobalEnv.new
      Signatures.build(genv)

      mdecls = @genv.resolve_method([:Class], false, :new)
      mdecls.each do |mdecl|
        mdecl.set_builtin do |ty, mid, args, ret|
          edges = []
          ty = ty.get_instance_type
          mds = genv.resolve_method(ty.cpath, ty.is_a?(Type::Class), :initialize)
          if mds
            mds.each do |md|
              case md
              when MethodDecl
                # TODO?
              when MethodDef
                edges << [args, md.arg]
              end
            end
          end
          edges << [Source.new(ty), ret]
        end
      end

      #@genv.system_sigs_loaded
      @text_nodes = {}
    end

    attr_reader :genv

    def update_file(path, code)
      prev_node = @text_nodes[path]
      version = prev_node ? prev_node.lenv.text_id.version + 1 : 0

      text_id = TextId.new(path, version)
      cref = CRef.new([], false, nil)
      lenv = LexicalScope.new(text_id, cref, nil)
      node = AST.parse(code, lenv)

      node.diff(@text_nodes[path]) if prev_node
      @text_nodes[path] = node

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
          raise
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
      vtxs.each do |vtx|
        case vtx
        when CallSite
          puts "\e[33m#{ vtx.long_inspect }\e[m"
          puts "  recv: #{ vtx.recv }"
          puts "  args: (#{ vtx.args })"
          puts "  ret: #{ vtx.ret }"
        end
      end
      vtxs.each do |vtx|
        case vtx
        when ReadSite
          puts "\e[32m#{ vtx.long_inspect }\e[m"
          puts "  ret: #{ vtx.ret }"
        end
      end
    end

    def hover(path, pos)
      @text_nodes[path].hover(pos)
    end

    def gotodefs(path, pos)
      obj = @text_nodes[path].hover(pos)
      case obj
      when CallSite
        code_ranges = []
        obj.recv.types.each_key do |ty|
          mdefs = genv.get_method_entity(ty.cpath, ty.is_a?(Type::Class), obj.mid).defs
          if mdefs
            mdefs.each do |mdef|
              code_ranges << mdef.node&.code_range
            end
          end
        end
        code_ranges.compact
      when Vertex
        # TODO
      end
    end

    def get_method_sig(cpath, singleton, mid)
      s = []
      @genv.get_method_entity(cpath, singleton, mid).defs.each do |mdef|
        s << "def #{ mid }: " + mdef.show
      end
      s
    end
  end
end