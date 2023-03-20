module TypeProf::Core
  class Builtin
    def initialize(genv)
      @genv = genv
    end

    def class_new(node, ty, mid, a_args, ret)
      edges = []
      ty = ty.get_instance_type
      recv = Source.new(ty)
      site = CallSite.new(node, @genv, recv, :initialize, a_args, nil) # TODO: block
      # TODO: dup check
      node.add_site(:class_new, site)
      # site.ret (the return value of initialize) is discarded
      edges << [Source.new(ty), ret]
    end

    def proc_call(node, ty, mid, a_args, ret)
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

    def module_attr_reader(node, ty, mid, a_args, ret)
      edges = []
      a_args.each do |a_arg|
        a_arg.types.each do |ty, _source|
          case ty
          when Type::Symbol
            ivar_name = :"@#{ ty.sym }"
            site = IVarReadSite.new(node, @genv, node.lenv.cref.cpath, false, ivar_name)
            # TODO: dup check
            node.add_site(:attr_reader, site)
            mdef = MethodDef.new(node.lenv.cref.cpath, false, ty.sym, node, [], nil, site.ret)
            node.add_def(@genv, mdef)
          else
            puts "???"
          end
        end
      end
      edges
    end

    def module_attr_accessor(node, ty, mid, a_args, ret)
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
            site = IVarReadSite.new(node, @genv, node.lenv.cref.cpath, false, ivar_name)
            # TODO: dup check
            node.add_site(:attr_writer, site)
            mdef = MethodDef.new(node.lenv.cref.cpath, false, ty.sym, node, [], nil, site.ret)
            node.add_def(@genv, mdef)
          else
            puts "???"
          end
        end
      end
      edges
    end

    def array_aset(node, ty, mid, a_args, ret)
      edges = []
      if a_args.size == 2
        case ty
        when Type::Array
          #idx = a_args[0].types
          val = a_args[1]
          edges << [val, ty.elem]
        else
          puts "???"
        end
      else
        puts "???"
      end
      edges
    end

    def deploy
      {
        class_new: [[:Class], false, :new],
        proc_call: [[:Proc], false, :call],
        module_attr_reader: [[:Module], false, :attr_reader],
        module_attr_accessor: [[:Module], false, :attr_accessor],
        array_aset: [[:Array], false, :[]=],
      }.each do |key, (cpath, singleton, mid)|
        mdecls = @genv.resolve_method(cpath, singleton, mid)
        m = method(key)
        mdecls.each do |mdecl|
          mdecl.set_builtin(&m)
        end
      end
    end
  end
end