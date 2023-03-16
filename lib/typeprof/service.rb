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
        mdecl.set_builtin do |node, ty, mid, a_args, ret|
          edges = []
          ty = ty.get_instance_type
          mds = genv.resolve_method(ty.cpath, ty.is_a?(Type::Module), :initialize)
          if mds
            mds.each do |md|
              case md
              when MethodDecl
                # TODO?
              when MethodDef
                if a_args.size == md.f_args.size
                  a_args.zip(md.f_args) do |a_arg, f_arg|
                    edges << [a_arg, f_arg]
                  end
                end
              end
            end
          end
          edges << [Source.new(ty), ret]
        end
      end

      mdecls = @genv.resolve_method([:Proc], false, :call)
      mdecls.each do |mdecl|
        mdecl.set_builtin do |node, ty, mid, a_args, ret|
          edges = []
          case ty
          when Type::Proc
            if a_args.size == ty.block.f_args.size
              a_args.zip(ty.block.f_args) do |a_arg, f_arg|
                edges << [a_arg, f_arg]
              end
            end
            edges << [ty.block.ret, ret]
          else
            puts "???"
          end
          edges
        end
      end

      mdecls = @genv.resolve_method([:Module], false, :attr_reader)
      mdecls.each do |mdecl|
        mdecl.set_builtin do |node, ty, mid, a_args, ret|
          edges = []
          a_args.each do |a_arg|
            a_arg.types.each do |ty, _source|
              case ty
              when Type::Symbol
                ivar_name = :"@#{ ty.sym }"
                site = IVarReadSite.new(self, @genv, node.lenv.cref.cpath, false, ivar_name)
                node.add_site(site)
                mdef = MethodDef.new(node.lenv.cref.cpath, false, ty.sym, node, [], nil, site.ret)
                node.add_def(@genv, mdef)
              else
                puts "???"
              end
            end
          end
          edges
        end
      end

      mdecls = @genv.resolve_method([:Module], false, :attr_accessor)
      mdecls.each do |mdecl|
        mdecl.set_builtin do |node, ty, mid, a_args, ret|
          edges = []
          a_args.each do |a_arg|
            a_arg.types.each do |ty, _source|
              case ty
              when Type::Symbol
                vtx = Vertex.new("attr_writer-arg", node)
                ivar_name = :"@#{ ty.sym }"
                ivdef = IVarDef.new(node.lenv.cref.cpath, false, ivar_name, node, vtx)
                node.add_def(@genv, ivdef)
                mdef = MethodDef.new(node.lenv.cref.cpath, false, :"#{ ty.sym }=", node, [vtx], nil, vtx)
                node.add_def(@genv, mdef)

                ivar_name = :"@#{ ty.sym }"
                site = IVarReadSite.new(self, @genv, node.lenv.cref.cpath, false, ivar_name)
                node.add_site(site)
                mdef = MethodDef.new(node.lenv.cref.cpath, false, ty.sym, node, [], nil, site.ret)
                node.add_def(@genv, mdef)
              else
                puts "???"
              end
            end
          end
          edges
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
      node = AST.parse(text_id, code)

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
          dump_graph("test0.rb")
          raise (live_vtxs.to_a & dead_vtxs.to_a).to_s
        end

        if live_boxes.to_a & dead_boxes.to_a != []
          raise
        end
      end
    end

    def dump_declarations(path)
      depth = 0
      @text_nodes[path].traverse do |event, node|
        case node
        when AST::MODULE
          if node.static_cpath
            if event == :enter
              puts " " * depth + "module #{ node.static_path.join("::") }"
              depth += 2
            else
              depth -= 2
              puts " " * depth + "end"
            end
          end
        when AST::CLASS
          if node.static_cpath && node.static_superclass_cpath
            if event == :enter
              puts " " * depth + "class #{ node.static_cpath.join("::") } < #{ node.static_superclass_cpath.join("::") }"
              depth += 2
            else
              depth -= 2
              puts " " * depth + "end"
            end
          end
        else
          if event == :enter && !node.defs.empty?
            node.defs.each do |d|
              case d
              when MethodDef
                #puts " " * depth + "# #{ d.node.code_range }"
                puts " " * depth + "def #{ d.mid }: " + d.show
              when ConstDef
                #puts " " * depth + "# #{ d.node.code_range }"
                puts " " * depth + "#{ d.cpath.join("::") }::#{ d.cname }: " + d.val.show
              end
            end
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

    def hover(path, pos)
      @text_nodes[path].hover(pos)
    end

    def gotodefs(path, pos)
      obj = @text_nodes[path].hover(pos)
      case obj
      when CallSite
        code_ranges = []
        obj.recv.types.each_key do |ty|
          me = MethodEntry.new(ty.cpath, ty.is_a?(Type::Module), obj.mid)
          mdefs = genv.get_method_entity(me).defs
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
      @genv.get_method_entity(MethodEntry.new(cpath, singleton, mid)).defs.each do |mdef|
        s << "def #{ mid }: " + mdef.show
      end
      s
    end
  end
end