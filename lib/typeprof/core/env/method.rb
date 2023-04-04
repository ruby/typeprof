module TypeProf::Core
  class MethodDecl
    def initialize(rbs_member)
      @rbs_member = rbs_member
    end

    attr_reader :rbs_member

    def resolve_overloads(changes, genv, node, param_map, a_args, block, ret)
      @rbs_member.overloads.each do |overload|
        rbs_func = overload.method_type.type
        # rbs_func.optional_keywords
        # rbs_func.optional_positionals
        # rbs_func.required_keywords
        # rbs_func.rest_keywords
        # rbs_func.rest_positionals
        # rbs_func.trailing_positionals
        param_map0 = param_map.dup
        overload.method_type.type_params.map do |param|
          param_map0[param.name] = Vertex.new("type-param:#{ param.name }", node)
        end
        f_args = rbs_func.required_positionals.map do |f_arg|
          Signatures.type_to_vtx(genv, node, f_arg.type, param_map0)
        end
        next if a_args.size != f_args.size
        next if !f_args.all? # skip interface type
        next if a_args.zip(f_args).any? {|a_arg, f_arg| !a_arg.match?(genv, f_arg) }
        rbs_blk = overload.method_type.block
        next if !!rbs_blk != !!block
        if rbs_blk && block
          rbs_blk_func = rbs_blk.type
          # rbs_blk_func.optional_keywords, ...
          block.types.each do |ty, _source|
            case ty
            when Type::Proc
              blk_a_args = rbs_blk_func.required_positionals.map do |blk_a_arg|
                Signatures.type_to_vtx(genv, node, blk_a_arg.type, param_map0)
              end
              blk_f_args = ty.block.f_args
              if blk_a_args.size == blk_f_args.size # TODO: pass arguments for block
                blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                  changes.add_edge(blk_a_arg, blk_f_arg)
                end
                blk_f_ret = Signatures.type_to_vtx(genv, node, rbs_blk_func.return_type, param_map0) # TODO: Sink instead of Source
                changes.add_edge(ty.block.ret, blk_f_ret)
              end
            end
          end
        end
        ret_vtx = Signatures.type_to_vtx(genv, node, rbs_func.return_type, param_map0)
        changes.add_edge(ret_vtx, ret)
      end
    end
  end

  class Block
    def initialize(node, f_args, ret)
      @node = node
      @f_args = f_args
      @ret = ret
    end

    attr_reader :node, :f_args, :ret
  end
end