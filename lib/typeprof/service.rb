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
    end

    def dump_graph(path)
      node = @text_nodes[path]

      vtxs = Set.new
      puts node.dump(vtxs)
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

    def show_graph(cpath, mid)
      mdefs = @genv.get_method_defs(cpath, mid)
      tyvars = {}
      callsites = {}
      name = -> obj do
        case obj
        when CallSite
          callsites[obj] ||= "c#{ callsites.size }@#{ obj.node&.code_range.inspect }"
        when Vertex
          tyvars[obj] ||= "v#{ tyvars.size }@#{ obj.show_name }@#{ obj.object_id }"
        when Source
          "<imm>"
        else
          raise obj.class.to_s
        end
      end
      visited = {}
      mdefs.each do |mdef|
        puts "#{ cpath.join("::") }##{ mdef.node.mid } @ #{ mdef.node.code_range.inspect }"
        puts "  arg: #{ name[mdef.arg] }"
        puts "  ret: #{ name[mdef.ret] }"
        stack = [mdef.ret, mdef.arg]
        until stack.empty?
          obj = stack.pop
          next if visited[obj]
          visited[obj] = true
          case obj
          when Vertex
            if obj.next_vtxs.empty?
              puts "  #{ name[obj] } has no edge"
            else
              obj.next_vtxs.each do |obj2|
                puts "  #{ name[obj] } -> #{ name[obj2] }"
                stack << obj2
              end
            end
          when Source
          when CallSite
            puts "  #{ name[obj] }:"
            puts "    recv=#{ name[obj.recv] }"
            puts "    args=(#{ name[obj.args] })"
            puts "    ret=#{ name[obj.ret] }"
            stack << obj.ret << obj.args << obj.recv
          else
            raise obj.class.to_s
          end
        end
      end
    end
  end
end