module TypeProf::Core
  class MethodEntity
    def initialize
      @builtin = nil
      @decls = Set[]
      @defs = Set[]
      @aliases = {}
    end

    attr_reader :decls, :defs, :aliases
    attr_accessor :builtin

    def add_decl(decl)
      @decls << decl
    end

    def remove_decl(decl)
      @decls.delete(decl)
    end

    def add_def(mdef)
      @defs << mdef
      self
    end

    def remove_def(mdef)
      @defs.delete(mdef)
    end

    def add_alias(node, old_mid)
      @aliases[node] = old_mid
    end

    def remove_alias(mid)
      @aliases.delete(mid)
    end

    def exist?
      @builtin || !@decls.empty? || !@defs.empty? || !@aliases.empty?
    end
  end

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

  class MethodDef
    def initialize(node, f_args, block, ret)
      @node = node
      raise unless f_args
      @f_args = f_args
      @block = block
      @ret = ret
    end

    attr_reader :node, :f_args, :block, :ret

    def call(changes, genv, call_node, a_args, block, ret)
      if a_args.size == @f_args.size
        if block && @block
          changes.add_edge(block, @block)
        end
        # check arity
        a_args.zip(@f_args) do |a_arg, f_arg|
          break unless f_arg
          changes.add_edge(a_arg, f_arg)
        end
        changes.add_edge(@ret, ret)
      else
        changes.add_diagnostic(
          TypeProf::Diagnostic.new(call_node, "wrong number of arguments (#{ a_args.size } for #{ @f_args.size })")
        )
      end
    end

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

  class Block
    def initialize(node, f_args, ret)
      @node = node
      @f_args = f_args
      @ret = ret
    end

    attr_reader :node, :f_args, :ret
  end
end