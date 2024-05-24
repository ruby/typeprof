module TypeProf::Core
  $box_counts = Hash.new(0)
  class Box
    def initialize(node)
      @node = node
      @changes = ChangeSet.new(node, self)
      @destroyed = false
      $box_counts[Box] += 1
      $box_counts[self.class] += 1
    end

    attr_reader :changes

    attr_reader :node, :destroyed

    def destroy(genv)
      $box_counts[self.class] -= 1
      $box_counts[Box] -= 1
      @destroyed = true
      @changes.reinstall(genv) # rollback all changes
    end

    def reuse(new_node)
      @node = new_node
      @changes.reuse(new_node)
    end

    def on_type_added(genv, src_tyvar, added_types)
      genv.add_run(self)
    end

    def on_type_removed(genv, src_tyvar, removed_types)
      genv.add_run(self)
    end

    def run(genv)
      return if @destroyed
      run0(genv, @changes)
      @changes.reinstall(genv)
    end

    def diagnostics(genv, &blk)
      raise self.to_s if !@changes
      @changes.diagnostics.each(&blk)
      @changes.boxes.each_value do |box|
        box.diagnostics(genv, &blk)
      end
    end

    #@@new_id = 0

    def to_s
      "#{ self.class.to_s.split("::").last[0] }#{ @id ||= $new_id += 1 }"
    end

    alias inspect to_s
  end

  class ConstReadBox < Box
    def initialize(node, genv, const_read)
      super(node)
      @const_read = const_read
      const_read.followers << self
      @ret = Vertex.new("cname", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv, changes)
      cdef = @const_read.cdef
      if cdef
        changes.add_depended_value_entity(cdef)
        changes.add_edge(genv, cdef.vtx, @ret)
      end
    end
  end

  class TypeReadBox < Box
    def initialize(node, genv, rbs_type)
      super(node)
      @rbs_type = rbs_type
      @ret = Vertex.new("type-read", node)
      genv.add_run(self)
    end

    attr_reader :node, :rbs_type, :ret

    def run0(genv, changes)
      vtx = @rbs_type.covariant_vertex(genv, changes, {})
      changes.add_edge(genv, vtx, @ret)
    end
  end

  class MethodDeclBox < Box
    def initialize(node, genv, cpath, singleton, mid, method_types, overloading)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      @method_types = method_types
      @overloading = overloading
      @ret = Source.new

      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.add_decl(self)
      me.add_run_all_method_call_boxes(genv)
      me.add_run_all_mdefs(genv)
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :method_types, :overloading, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.remove_decl(self)
      me.add_run_all_method_call_boxes(genv)
    end

    def match_arguments?(genv, changes, param_map, a_args, method_type)
      # TODO: handle a tuple as a splat argument?
      if a_args.splat_flags.any?
        return false unless method_type.rest_positionals
        method_type.req_positionals.size.times do |i|
          return false if a_args.splat_flags[i]
        end
        method_type.post_positionals.size.times do |i|
          return false if a_args.splat_flags[-i - 1]
        end
      else
        actual = a_args.positionals.size
        required_formal = method_type.req_positionals.size + method_type.post_positionals.size
        if actual < required_formal
          # too few actual arguments
          return false
        end
        if !method_type.rest_positionals && actual > required_formal + method_type.opt_positionals.size
          # too many actual arguments
          return false
        end
      end

      method_type.req_positionals.each_with_index do |ty, i|
        f_arg = ty.contravariant_vertex(genv, changes, param_map)
        return false unless a_args.positionals[i].check_match(genv, changes, f_arg)
      end
      method_type.post_positionals.each_with_index do |ty, i|
        f_arg = ty.contravariant_vertex(genv, changes, param_map)
        i -= method_type.post_positionals.size
        return false unless a_args.positionals[i].check_match(genv, changes, f_arg)
      end

      start_rest = method_type.req_positionals.size
      end_rest = a_args.positionals.size - method_type.post_positionals.size

      i = 0
      while i < method_type.opt_positionals.size && start_rest < end_rest
        break if a_args.splat_flags[start_rest]
        f_arg = method_type.opt_positionals[i].contravariant_vertex(genv, changes, param_map)
        return false unless a_args.positionals[start_rest].check_match(genv, changes, f_arg)
        i += 1
        start_rest += 1
      end

      if start_rest < end_rest
        vtxs = a_args.get_rest_args(genv, start_rest, end_rest)
        while i < method_type.opt_positionals.size
          f_arg = method_type.opt_positionals[i].contravariant_vertex(genv, changes, param_map)
          return false if vtxs.any? {|vtx| !vtx.check_match(genv, changes, f_arg) }
          i += 1
        end
        if method_type.rest_positionals
          f_arg = method_type.rest_positionals.contravariant_vertex(genv, changes, param_map)
          return false if vtxs.any? {|vtx| !vtx.check_match(genv, changes, f_arg) }
        end
      end

      return true
    end

    def resolve_overloads(changes, genv, node, param_map, a_args, ret)
      match_any_overload = false
      @method_types.each do |method_type|
        param_map0 = param_map.dup
        if method_type.type_params
          method_type.type_params.map do |var|
            vtx = Vertex.new("ty-var-#{ var }", node)
            param_map0[var] = vtx
          end
        end

        next unless match_arguments?(genv, changes, param_map0, a_args, method_type)

        rbs_blk = method_type.block
        next if method_type.block_required && !a_args.block
        next if !rbs_blk && a_args.block
        if rbs_blk && a_args.block
          # rbs_blk_func.optional_keywords, ...
          a_args.block.each_type do |ty|
            case ty
            when Type::Proc
              blk_f_ret = rbs_blk.return_type.contravariant_vertex(genv, changes, param_map0)
              blk_a_args = rbs_blk.req_positionals.map do |blk_a_arg|
                blk_a_arg.covariant_vertex(genv, changes, param_map0)
              end

              ty.block.accept_args(genv, changes, blk_a_args, blk_f_ret, true)
            end
          end
        end
        ret_vtx = method_type.return_type.covariant_vertex(genv, changes, param_map0)
        changes.add_edge(genv, ret_vtx, ret)
        match_any_overload = true
      end
      unless match_any_overload
        meth = node.mid_code_range ? :mid_code_range : :code_range
        changes.add_diagnostic(meth, "failed to resolve overloads")
      end
    end

    def show
      @method_types.map do |method_type|
        args = []
        method_type.req_positionals.each do |arg|
          args << arg.show
        end
        # TODO
        method_type.opt_positionals
        method_type.rest_positionals
        method_type.post_positionals
        # method_type.req_keywords
        # method_type.req_keywords
        s = args.empty? ? "-> " : "(#{ args.join(", ") }) -> "
        s += method_type.return_type.show
      end.join(" | ")
    end
  end

  class EscapeBox < Box
    def initialize(node, genv, a_ret, f_ret)
      super(node)
      @a_ret = a_ret
      @f_ret = f_ret
      @f_ret.add_edge(genv, self)
    end

    attr_reader :a_ret, :f_ret

    def ret = @a_ret

    def run0(genv, changes)
      unless @a_ret.check_match(genv, changes, @f_ret)
        msg = "expected: #{ @f_ret.show }; actual: #{ @a_ret.show }"
        case @node
        when AST::ReturnNode
          changes.add_diagnostic(:code_range, msg)
        when AST::DefNode
          changes.add_diagnostic(:last_stmt_code_range, msg)
        when AST::NextNode
          changes.add_diagnostic(:code_range, msg)
        when AST::CallNode
          changes.add_diagnostic(:block_last_stmt_code_range, msg)
        else
          pp @node.class
        end
      end
    end
  end

  class MethodDefBox < Box
    def initialize(node, genv, cpath, singleton, mid, f_args, ret_boxes)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      raise unless f_args
      @f_args = f_args
      raise unless f_args.is_a?(FormalArguments)

      @record_block = RecordBlock.new(@node)
      if @f_args.block
        record_blk_ty = Source.new(Type::Proc.new(genv, @record_block))
        record_blk_ty.add_edge(genv, @f_args.block)
      end

      @ret_boxes = ret_boxes
      @ret = Vertex.new("ret:#{ mid }", node)
      ret_boxes.each do |box|
        @changes.add_edge(genv, box.ret, @ret)
      end
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.add_def(self)
      if me.decls.empty?
        me.add_run_all_method_call_boxes(genv)
      else
        genv.add_run(self)
      end
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :f_args, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.remove_def(self)
      if me.decls.empty?
        me.add_run_all_method_call_boxes(genv)
      else
        genv.add_run(self)
      end
      super(genv)
    end

    def run0(genv, changes)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      return if me.decls.empty?

      # TODO: support "| ..."
      decl = me.decls.to_a.first
      # TODO: support overload?
      method_type = decl.method_types.first
      _block = method_type.block

      mod = genv.resolve_cpath(@cpath)
      ty = @singleton ? Type::Singleton.new(genv, mod) : Type::Instance.new(genv, mod, []) # TODO: type params
      param_map0 = Type.default_param_map(genv, ty)

      positional_args = []
      splat_flags = []

      method_type.req_positionals.each do |a_arg|
        positional_args << a_arg.contravariant_vertex(genv, changes, param_map0)
        splat_flags << false
      end
      method_type.opt_positionals.each do |a_arg|
        positional_args << a_arg.contravariant_vertex(genv, changes, param_map0)
        splat_flags << false
      end
      if method_type.rest_positionals
        elems = method_type.rest_positionals.contravariant_vertex(genv, changes, param_map0)
        positional_args << Source.new(genv.gen_ary_type(elems))
        splat_flags << true
      end
      method_type.post_positionals.each do |a_arg|
        positional_args << a_arg.contravariant_vertex(genv, changes, param_map0)
        splat_flags << false
      end

      a_args = ActualArguments.new(positional_args, splat_flags, nil, nil) # TODO: keywords and block
      if pass_positionals(changes, genv, a_args)
        # TODO: block
        f_ret = method_type.return_type.contravariant_vertex(genv, changes, param_map0)
        @ret_boxes.each do |ret_box|
          changes.add_edge(genv, f_ret, ret_box.f_ret)
        end
      end
    end

    def pass_positionals(changes, genv, a_args)
      if a_args.splat_flags.any?
        # there is at least one splat actual argument

        lower = @f_args.req_positionals.size + @f_args.post_positionals.size
        upper = @f_args.rest_positionals ? nil : lower + @f_args.opt_positionals.size
        if upper && upper < a_args.positionals.size
          meth = changes.node.mid_code_range ? :mid_code_range : :code_range
          err = "#{ a_args.positionals.size } for #{ lower }#{ upper ? lower < upper ? "...#{ upper }" : "" : "+" }"
          changes.add_diagnostic(meth, "wrong number of arguments (#{ err })")
          return false
        end

        start_rest = [a_args.splat_flags.index(true), @f_args.req_positionals.size + @f_args.opt_positionals.size].min
        end_rest = [a_args.splat_flags.rindex(true) + 1, a_args.positionals.size - @f_args.post_positionals.size].max
        rest_vtxs = a_args.get_rest_args(genv, start_rest, end_rest)

        @f_args.req_positionals.each_with_index do |f_vtx, i|
          if i < start_rest
            changes.add_edge(genv, a_args.positionals[i], f_vtx)
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(genv, vtx, f_vtx)
            end
          end
        end
        @f_args.opt_positionals.each_with_index do |f_vtx, i|
          i += @f_args.opt_positionals.size
          if i < start_rest
            changes.add_edge(genv, a_args.positionals[i], f_vtx)
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(genv, vtx, f_vtx)
            end
          end
        end
        @f_args.post_positionals.each_with_index do |f_vtx, i|
          i += a_args.positionals.size - @f_args.post_positionals.size
          if end_rest <= i
            changes.add_edge(genv, a_args.positionals[i], f_vtx)
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(genv, vtx, f_vtx)
            end
          end
        end

        if @f_args.rest_positionals
          rest_vtxs.each do |vtx|
            changes.add_edge(genv, vtx, @f_args.rest_positionals)
          end
        end
      else
        # there is no splat actual argument

        lower = @f_args.req_positionals.size + @f_args.post_positionals.size
        upper = @f_args.rest_positionals ? nil : lower + @f_args.opt_positionals.size
        if a_args.positionals.size < lower || (upper && upper < a_args.positionals.size)
          meth = changes.node.mid_code_range ? :mid_code_range : :code_range
          err = "#{ a_args.positionals.size } for #{ lower }#{ upper ? lower < upper ? "...#{ upper }" : "" : "+" }"
          changes.add_diagnostic(meth, "wrong number of arguments (#{ err })")
          return false
        end

        @f_args.req_positionals.each_with_index do |f_vtx, i|
          changes.add_edge(genv, a_args.positionals[i], f_vtx)
        end
        @f_args.post_positionals.each_with_index do |f_vtx, i|
          i -= @f_args.post_positionals.size
          changes.add_edge(genv, a_args.positionals[i], f_vtx)
        end
        start_rest = @f_args.req_positionals.size
        end_rest = a_args.positionals.size - @f_args.post_positionals.size
        i = 0
        while i < @f_args.opt_positionals.size && start_rest < end_rest
          f_arg = @f_args.opt_positionals[i]
          changes.add_edge(genv, a_args.positionals[start_rest], f_arg)
          i += 1
          start_rest += 1
        end

        if start_rest < end_rest
          if @f_args.rest_positionals
            f_arg = @f_args.rest_positionals
            (start_rest..end_rest-1).each do |i|
              changes.add_edge(genv, a_args.positionals[i], f_arg)
            end
          end
        end
      end
      return true
    end

    def call(changes, genv, a_args, ret)
      if pass_positionals(changes, genv, a_args)
        changes.add_edge(genv, a_args.block, @f_args.block) if @f_args.block && a_args.block

        changes.add_edge(genv, @ret, ret)
      end
    end

    def show
      block_show = []
      if @record_block.used
        blk_f_args = @record_block.f_args.map {|arg| arg.show }.join(", ")
        blk_ret = @record_block.ret.show
        block_show << "{ (#{ blk_f_args }) -> #{ blk_ret } }"
      end
      args = []
      @f_args.req_positionals.each do |f_vtx|
        args << Type.strip_parens(f_vtx.show)
      end
      @f_args.opt_positionals.each do |f_vtx|
        args << ("?" + Type.strip_parens(f_vtx.show))
      end
      if @f_args.rest_positionals
        args << ("*" + Type.strip_parens(@f_args.rest_positionals.show))
      end
      @f_args.post_positionals.each do |var|
        args << Type.strip_parens(var.show)
      end
      if @node.is_a?(AST::DefNode)
        @node.req_keywords.zip(@f_args.req_keywords) do |name, f_vtx|
          args << "#{ name }: #{Type.strip_parens(f_vtx.show)}"
        end
        @node.opt_keywords.zip(@f_args.opt_keywords) do |name, f_vtx|
          args << "?#{ name }: #{Type.strip_parens(f_vtx.show)}"
        end
      end
      if @f_args.rest_keywords
        args << "**#{ Type.strip_parens(@f_args.rest_keywords.show) }"
      end
      args = args.join(", ")
      s = args.empty? ? [] : ["(#{ args })"]
      s << "#{ block_show.sort.join(" | ") }" unless block_show.empty?
      s << "-> #{ @ret.show }"
      s.join(" ")
    end
  end

  class MethodAliasBox < Box
    def initialize(node, genv, cpath, singleton, new_mid, old_mid)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @new_mid = new_mid
      @old_mid = old_mid
      @ret = Source.new(genv.nil_type)

      me = genv.resolve_method(@cpath, @singleton, @new_mid)
      me.add_alias(self, @old_mid)
      if me.decls.empty?
        me.add_run_all_method_call_boxes(genv)
      else
        genv.add_run(self)
      end
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :new_mid, :old_mid, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @new_mid)
      me.remove_alias(self)
      if me.decls.empty?
        me.add_run_all_method_call_boxes(genv)
      else
        genv.add_run(self)
      end
      super(genv)
    end

    def run0(genv, changes)
      # TODO: what to do?
    end
  end

  class MethodCallBox < Box
    def initialize(node, genv, recv, mid, a_args, subclasses)
      raise mid.to_s unless mid
      super(node)
      @recv = recv.new_vertex(genv, "recv:#{ mid }", node)
      @recv.add_edge(genv, self)
      @mid = mid
      @a_args = a_args.new_vertexes(genv, mid, node)
      @a_args.positionals.each {|arg| arg.add_edge(genv, self) }
      @a_args.block.add_edge(genv, self) if @a_args.block
      @ret = Vertex.new("ret:#{ mid }", node)
      @subclasses = subclasses
    end

    attr_reader :recv, :mid, :ret

    def run0(genv, changes)
      edges = Set[]
      called_mdefs = Set[]
      error_count = 0
      resolve(genv, changes) do |me, ty, mid, orig_ty|
        if !me
          # TODO: undefined method error
          if error_count < 3
            meth = @node.mid_code_range ? :mid_code_range : :code_range
            changes.add_diagnostic(meth, "undefined method: #{ orig_ty.show }##{ mid }")
          end
          error_count += 1
        elsif me.builtin
          # TODO: block? diagnostics?
          me.builtin[changes, @node, orig_ty, @a_args, @ret]
        elsif !me.decls.empty?
          # TODO: support "| ..."
          me.decls.each do |mdecl|
            # TODO: union type is ok?
            # TODO: add_depended_method_entity for types used to resolve overloads
            ty_env = Type.default_param_map(genv, orig_ty)
            if ty.is_a?(Type::Instance)
              ty.mod.type_params.zip(ty.args) do |param, arg|
                ty_env[param] = arg
              end
            end
            mdecl.resolve_overloads(changes, genv, @node, ty_env, @a_args, @ret)
          end
        elsif !me.defs.empty?
          me.defs.each do |mdef|
            next if called_mdefs.include?(mdef)
            called_mdefs << mdef
            mdef.call(changes, genv, @a_args, @ret)
          end
        else
          pp me
          raise
        end
      end
      if @subclasses
        resolve_subclasses(genv, changes) do |recv_ty, me|
          if !me.defs.empty?
            me.defs.each do |mdef|
              next if called_mdefs.include?(mdef)
              called_mdefs << mdef
              mdef.call(changes, genv, @a_args, @ret)
            end
          end
        end
      end
      edges.each do |src, dst|
        changes.add_edge(genv, src, dst)
      end
      if error_count > 3
        meth = @node.mid_code_range ? :mid_code_range : :code_range
        changes.add_diagnostic(meth, "... and other #{ error_count - 3 } errors")
      end
    end

    def resolve(genv, changes, &blk)
      @recv.each_type do |orig_ty|
        next if orig_ty == Type::Bot.new(genv)
        if @mid == :"*super"
          mid = @node.lenv.cref.mid
          skip = true
        else
          mid = @mid
          skip = false
        end

        ty = orig_ty.base_type(genv)

        base_ty_env = Type.default_param_map(genv, ty)

        while ty
          unless skip
            me = ty.mod.get_method(ty.is_a?(Type::Singleton), mid)
            changes.add_depended_method_entity(me) if changes
            if !me.aliases.empty?
              mid = me.aliases.values.first
              redo
            end
            if me.exist?
              yield me, ty, mid, orig_ty
              break
            end
          end

          skip = false

          if ty.is_a?(Type::Singleton)
            # TODO: extended modules
          else
            break if resolve_included_modules(genv, changes, base_ty_env, ty, mid) do |me, ty, mid|
              yield me, ty, mid, orig_ty
            end
          end

          ty = genv.get_superclass_type(ty, changes, base_ty_env)
        end

        yield nil, nil, mid, orig_ty unless ty
      end
    end

    def resolve_included_modules(genv, changes, base_ty_env, ty, mid, &blk)
      found = false

      ty.mod.self_types.each do |(mdecl, idx), self_ty_mod|
        raise unless mdecl.is_a?(AST::SigModuleNode)
        if self_ty_mod.type_params
          self_ty = genv.get_instance_type(self_ty_mod, mdecl.self_type_args[idx], changes, base_ty_env, ty)
        else
          self_ty = Type::Instance.new(genv, self_ty_mod, [])
        end

        me = self_ty.mod.get_method(false, mid)
        changes.add_depended_method_entity(me) if changes
        if !me.aliases.empty?
          mid = me.aliases.values.first
          redo
        end
        if me.exist?
          found = true
          yield me, self_ty, mid
        else
          found ||= resolve_included_modules(genv, changes, base_ty_env, self_ty, mid, &blk)
        end
      end

      ty.mod.included_modules.each do |inc_decl, inc_mod|
        if inc_decl.is_a?(AST::SigIncludeNode) && inc_mod.type_params
          inc_ty = genv.get_instance_type(inc_mod, inc_decl.args, changes, base_ty_env, ty)
        else
          inc_ty = Type::Instance.new(genv, inc_mod, [])
        end

        me = inc_ty.mod.get_method(false, mid)
        changes.add_depended_method_entity(me) if changes
        if !me.aliases.empty?
          mid = me.aliases.values.first
          redo
        end
        if me.exist?
          found = true
          yield me, inc_ty, mid
        else
          found ||= resolve_included_modules(genv, changes, base_ty_env, inc_ty, mid, &blk)
        end
      end
      found
    end

    def resolve_subclasses(genv, changes)
      # TODO: This does not follow new subclasses
      @recv.each_type do |ty|
        next if ty == Type::Bot.new(genv)
        base_ty = ty.base_type(genv)
        singleton = base_ty.is_a?(Type::Singleton)
        mod = base_ty.mod
        mod.each_descendant do |desc_mod|
          next if mod == desc_mod
          me = desc_mod.get_method(singleton, @mid)
          changes.add_depended_method_entity(me)
          if me && me.exist?
            yield ty, me
          end
        end
      end
    end
  end

  class GVarReadBox < Box
    def initialize(node, genv, name)
      super(node)
      @vtx = genv.resolve_gvar(name).vtx
      @ret = Vertex.new("gvar", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv, changes)
      changes.add_edge(genv, @vtx, @ret)
    end
  end

  class IVarReadBox < Box
    def initialize(node, genv, cpath, singleton, name)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @name = name
      genv.resolve_cpath(cpath).ivar_reads << self
      @proxy = Vertex.new("ivar", node)
      @ret = Vertex.new("ivar", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def destroy(genv)
      genv.resolve_cpath(@cpath).ivar_reads.delete(self)
      super(genv)
    end

    def run0(genv, changes)
      mod = genv.resolve_cpath(@cpath)
      singleton = @singleton
      cur_ive = mod.get_ivar(singleton, @name)
      target_vtx = nil
      genv.each_direct_superclass(mod, singleton) do |mod, singleton|
        ive = mod.get_ivar(singleton, @name)
        if ive.exist?
          target_vtx = ive.vtx
        end
      end
      edges = []
      if target_vtx
        if target_vtx != cur_ive.vtx
          edges << [cur_ive.vtx, @proxy] << [@proxy, target_vtx]
        end
        edges << [target_vtx, @ret]
      else
        # TODO: error?
      end
      edges.each do |src, dst|
        changes.add_edge(genv, src, dst)
      end
    end
  end

  class MAsgnBox < Box
    def initialize(node, genv, rhs, lhss)
      super(node)
      @rhs = rhs
      @lhss = lhss
      @rhs.add_edge(genv, self)
    end

    attr_reader :node, :rhs, :lhss

    def destroy(genv)
      @rhs.remove_edge(genv, self) # TODO: Is this really needed?
      super(genv)
    end

    def ret = @rhs

    def run0(genv, changes)
      edges = []
      @rhs.each_type do |ty|
        case ty
        when Type::Array
          @lhss.each_with_index do |lhs, i|
            edges << [ty.get_elem(genv, i), lhs]
          end
        else
          edges << [Source.new(ty), @lhss[0]]
        end
      end
      edges.each do |src, dst|
        changes.add_edge(genv, src, dst)
      end
    end
  end
end
