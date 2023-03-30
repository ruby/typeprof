module TypeProf::Core
  class MethodEntry
    def initialize(cpath, singleton, mid)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
    end

    attr_reader :cpath, :singleton, :mid
  end

  class MethodDeclOld < MethodEntry
    def initialize(cpath, singleton, mid, rbs_member)
      super(cpath, singleton, mid)
      @rbs_member = rbs_member
      @builtin = nil
    end

    attr_reader :rbs_member, :builtin

    def resolve_overloads(genv, node, recv_ty, a_args, block, ret)
      all_edges = Set[]
      self_ty = (@singleton ? Type::Module : Type::Instance).new(@cpath)
      param_map = {
        __self: Source.new(self_ty),
      }
      case recv_ty
      when Type::Array
        case recv_ty.base_types(genv).first.cpath
        when [:Set]
          param_map[:A] = recv_ty.get_elem
        when [:Array], [:Enumerator]
          param_map[:Elem] = recv_ty.get_elem
        end
      when Type::Hash
        param_map[:K] = recv_ty.get_key
        param_map[:V] = recv_ty.get_value
      end
      @rbs_member.overloads.each do |overload|
        edges = Set[]
        func = overload.method_type.type
        # func.optional_keywords
        # func.optional_positionals
        # func.required_keywords
        # func.rest_keywords
        # func.rest_positionals
        # func.trailing_positionals
        param_map0 = param_map.dup
        overload.method_type.type_params.map do |param|
          param_map0[param.name] = Vertex.new("type-param:#{ param.name }", node)
        end
        #puts; p [@cpath, @singleton, @mid]
        f_args = func.required_positionals.map do |f_arg|
          Signatures.type_to_vtx(genv, node, f_arg.type, param_map0)
        end
        # TODO: correct block match
        if a_args.size == f_args.size && f_args.all? # skip interface type
          match = a_args.zip(f_args).all? do |a_arg, f_arg|
            a_arg.match?(genv, f_arg)
          end
          rbs_blk = overload.method_type.block
          if block
            blk = overload.method_type.block
            if blk
              blk_func = rbs_blk.type
              # blk_func.optional_keywords
              # ..
              block.types.each do |ty, _source|
                case ty
                when Type::Proc
                  blk_a_args = blk_func.required_positionals.map do |blk_a_arg|
                    Signatures.type_to_vtx(genv, node, blk_a_arg.type, param_map0)
                  end
                  blk_f_args = ty.block.f_args
                  if blk_a_args.size == blk_f_args.size
                    blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                      edges << [blk_a_arg, blk_f_arg]
                    end
                    blk_f_ret = Signatures.type_to_vtx(genv, node, blk_func.return_type, param_map0)
                    ty.block.ret.add_edge(genv, blk_f_ret)
                  else
                    match = false
                  end
                else
                  "???"
                end
              end
            else
              match = false
            end
          else
            if rbs_blk
              match = false
            end
          end
          if match
            ret_vtx = Signatures.type_to_vtx(genv, node, func.return_type, param_map0)
            edges << [ret_vtx, ret]
            edges.each do |src, dst|
              all_edges << [src, dst]
            end
          end
        end
      end
      all_edges
    end

    def set_builtin(&blk)
      @builtin = blk
    end

    def inspect
      "#<MethodDeclOld ...>"
    end
  end

  class MethodDefOld < MethodEntry
    def initialize(cpath, singleton, mid, node, f_args, block, ret)
      super(cpath, singleton, mid)
      @node = node
      raise unless f_args
      @f_args = f_args
      @block = block
      @ret = ret
    end

    attr_reader :cpath, :singleton, :mid, :node, :f_args, :block, :ret

    def show
      block_show = []
      if @block
        @block.types.each_key do |ty|
          case ty
          when Type::Proc
            block_show << "{ (#{ ty.block.f_args.map {|arg| arg.show }.join(", ") }) -> #{ ty.block.ret.show } }"
          else
            puts "???"
          end
        end
      end
      s = []
      s << "(#{ @f_args.map {|arg| Type.strip_parens(arg.show) }.join(", ") })" unless @f_args.empty?
      s << "#{ block_show.sort.join(" | ") }" unless block_show.empty?
      s << "-> #{ @ret.show }"
      s.join(" ")
    end
  end

  class MethodAlias < MethodEntry
    def initialize(cpath, singleton, new_mid, old_mid, source)
      super(cpath, singleton, new_mid)
      @old_mid = old_mid
      @source = source
    end

    attr_reader :old_mid, :source
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