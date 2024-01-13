module TypeProf::Core
  class Changes
    def initialize(target)
      @target = target
      @covariant_types = {}
      @edges = []
      @new_edges = []
      @sites = {}
      @new_sites = {}
      @diagnostics = []
      @new_diagnostics = []
      @depended_method_entities = []
      @new_depended_method_entities = []
      @depended_static_reads = []
      @new_depended_static_reads = []
      @depended_superclasses = []
      @new_depended_superclasses = []
    end

    attr_reader :sites, :diagnostics, :covariant_types

    def new_vertex(genv, sig_type_node, subst)
      @covariant_types[sig_type_node] ||= Vertex.new("rbs_type", sig_type_node)
    end

    def add_edge(src, dst)
      raise unless src.is_a?(BasicVertex)
      @new_edges << [src, dst]
    end

    # TODO: if an edge is removed during one analysis, we may need to remove sub-sites?

    def add_callsite(genv, node, recv, mid, a_args, subclasses)
      key = [:callsite, node, recv, mid, a_args, subclasses]
      return if @new_sites[key]
      @new_sites[key] = CallSite.new(node, genv, recv, mid, a_args, subclasses)
    end

    def add_check_return_site(genv, node, a_ret, f_ret)
      key = [:check_return, node, a_ret, f_ret]
      return if @new_sites[key]
      @new_sites[key] = CheckReturnSite.new(node, genv, a_ret, f_ret)
    end

    def add_masgn_site(genv, node, rhs, lhss)
      key = [:masgn, node, rhs, lhss]
      return if @new_sites[key]
      @new_sites[key] = MAsgnSite.new(node, genv, rhs, lhss)
    end

    def add_diagnostic(diag)
      @new_diagnostics << diag
    end

    def add_depended_method_entities(me)
      @new_depended_method_entities << me
    end

    def add_depended_static_read(static_read)
      @new_depended_static_reads << static_read
    end

    def add_depended_superclass(mod)
      @new_depended_superclasses << mod
    end

    def reinstall(genv)
      @new_edges.uniq!
      @new_edges.each do |src, dst|
        src.add_edge(genv, dst) unless @edges.include?([src, dst])
      end
      @edges.each do |src, dst|
        src.remove_edge(genv, dst) unless @new_edges.include?([src, dst])
      end
      @edges, @new_edges = @new_edges, @edges
      @new_edges.clear

      @sites.each do |key, site|
        site.destroy(genv)
      end
      @sites, @new_sites = @new_sites, @sites
      @new_sites.clear

      @diagnostics, @new_diagnostics = @new_diagnostics, @diagnostics
      @new_diagnostics.clear

      @depended_method_entities.each do |me|
        me.callsites.delete(@target) || raise
      end
      @new_depended_method_entities.uniq!
      @new_depended_method_entities.each do |me|
        me.callsites << @target
      end

      @depended_method_entities, @new_depended_method_entities = @new_depended_method_entities, @depended_method_entities
      @new_depended_method_entities.clear

      @depended_static_reads.each do |static_read|
        static_read.followers.delete(@target)
      end
      @new_depended_static_reads.uniq!
      @new_depended_static_reads.each do |static_read|
        static_read.followers << @target
      end

      @depended_static_reads, @new_depended_static_reads = @new_depended_static_reads, @depended_static_reads
      @new_depended_static_reads.clear

      @depended_superclasses.each do |mod|
        mod.subclass_checks.delete(@target)
      end
      @new_depended_superclasses.uniq!
      @new_depended_superclasses.each do |mod|
        mod.subclass_checks << @target
      end

      @depended_superclasses, @new_depended_superclasses = @new_depended_superclasses, @depended_superclasses
      @new_depended_superclasses.clear
    end
  end

  $site_counts = Hash.new(0)
  class Site
    def initialize(node)
      @node = node
      @changes = Changes.new(self)
      @destroyed = false
      $site_counts[Site] += 1
      $site_counts[self.class] += 1
    end

    attr_reader :changes

    attr_reader :node, :destroyed

    def destroy(genv)
      $site_counts[self.class] -= 1
      $site_counts[Site] -= 1
      @destroyed = true
      @changes.reinstall(genv) # rollback all changes
    end

    def reuse(node)
      @node = node
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
      @changes.sites.each_value do |site|
        site.diagnostics(genv, &blk)
      end
    end

    #@@new_id = 0

    def to_s
      "#{ self.class.to_s.split("::").last[0] }#{ @id ||= $new_id += 1 }"
    end

    alias inspect to_s
  end

  class ConstReadSite < Site
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
      changes.add_edge(cdef.vtx, @ret) if cdef
    end

    def long_inspect
      "#{ to_s } (cname:#{ @cname } @ #{ @node.code_range })"
    end
  end

  class TypeReadSite < Site
    def initialize(node, genv, rbs_type)
      super(node)
      @rbs_type = rbs_type
      @ret = Vertex.new("type-read", node)
      genv.add_run(self)
    end

    attr_reader :node, :rbs_type, :ret

    def run0(genv, changes)
      vtx = @rbs_type.covariant_vertex(genv, changes, {})
      changes.add_edge(vtx, @ret)
    end

    def long_inspect
      "#{ to_s } (type-read:#{ @cname } @ #{ @node.code_range })"
    end
  end

  class MethodDeclSite < Site
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
      me.add_run_all_callsites(genv)
      me.add_run_all_mdefs(genv)
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :method_types, :overloading, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.remove_decl(self)
      me.add_run_all_callsites(genv)
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
          a_args.block.types.each do |ty, _source|
            case ty
            when Type::Proc
              blk_f_ret = rbs_blk.return_type.contravariant_vertex(genv, changes, param_map0)
              changes.add_check_return_site(genv, ty.block.node, ty.block.ret, blk_f_ret)

              blk_a_args = rbs_blk.req_positionals.map do |blk_a_arg|
                blk_a_arg.covariant_vertex(genv, changes, param_map0)
              end
              blk_f_args = ty.block.f_args
              # TODO: lambda?
              if blk_a_args.size == 1 && blk_f_args.size >= 2
                changes.add_masgn_site(genv, ty.block.node, blk_a_args[0], blk_f_args)
              else
                blk_a_args.zip(blk_f_args) do |blk_a_arg, blk_f_arg|
                  next unless blk_f_arg
                  changes.add_edge(blk_a_arg, blk_f_arg)
                end
              end
            end
          end
        end
        ret_vtx = method_type.return_type.covariant_vertex(genv, changes, param_map0)
        changes.add_edge(ret_vtx, ret)
        match_any_overload = true
      end
      unless match_any_overload
        meth = node.mid_code_range ? :mid_code_range : :code_range
        changes.add_diagnostic(
          TypeProf::Diagnostic.new(node, meth, "failed to resolve overloads")
        )
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

  class CheckReturnSite < Site
    def initialize(node, genv, a_ret, f_ret)
      super(node)
      @a_ret = a_ret
      @f_ret = f_ret
      @a_ret.add_edge(genv, self)
      genv.add_run(self)
    end

    def destroy(genv)
      @a_ret.remove_edge(genv, self) # TODO: Is this really needed?
      super(genv)
    end

    def ret = @a_ret

    def run0(genv, changes)
      unless @a_ret.check_match(genv, changes, @f_ret)
        @node.each_return_node do |node|
          next if node.ret.check_match(genv, changes, @f_ret)

          node = node.stmts.last if node.is_a?(AST::BLOCK)
          changes.add_diagnostic(
            TypeProf::Diagnostic.new(node, :code_range, "expected: #{ @f_ret.show }; actual: #{ node.ret.show }")
          )
        end
      end
    end
  end

  class MethodDefSite < Site
    def initialize(node, genv, cpath, singleton, mid, f_args, f_arg_vtxs, block, ret)
      super(node)
      @cpath = cpath
      @singleton = singleton
      @mid = mid
      raise unless f_args
      @f_args = f_args
      raise unless f_args.is_a?(FormalArguments)
      @f_arg_vtxs = f_arg_vtxs
      raise unless f_arg_vtxs.is_a?(Hash)
      @block = block
      @ret = ret
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.add_def(self)
      if me.decls.empty?
        me.add_run_all_callsites(genv)
      else
        genv.add_run(self)
      end
    end

    attr_accessor :node

    attr_reader :cpath, :singleton, :mid, :f_args, :f_arg_vtxs, :block, :ret

    def destroy(genv)
      me = genv.resolve_method(@cpath, @singleton, @mid)
      me.remove_def(self)
      if me.decls.empty?
        me.add_run_all_callsites(genv)
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
      if pass_positionals(changes, genv, nil, a_args)
        # TODO: block
        f_ret = method_type.return_type.contravariant_vertex(genv, changes, param_map0)
        changes.add_check_return_site(genv, @node, @ret, f_ret)
      end
    end

    def pass_positionals(changes, genv, call_node, a_args)
      if a_args.splat_flags.any?
        # there is at least one splat actual argument

        lower = @f_args.req_positionals.size + @f_args.post_positionals.size
        upper = @f_args.rest_positionals ? nil : lower + @f_args.opt_positionals.size
        if upper && upper < a_args.positionals.size
          if call_node
            meth = call_node.mid_code_range ? :mid_code_range : :code_range
            err = "#{ a_args.positionals.size } for #{ lower }#{ upper ? lower < upper ? "...#{ upper }" : "" : "+" }"
            changes.add_diagnostic(
              TypeProf::Diagnostic.new(call_node, meth, "wrong number of arguments (#{ err })")
            )
          end
          return false
        end

        start_rest = [a_args.splat_flags.index(true), @f_args.req_positionals.size + @f_args.opt_positionals.size].min
        end_rest = [a_args.splat_flags.rindex(true) + 1, a_args.positionals.size - @f_args.post_positionals.size].max
        rest_vtxs = a_args.get_rest_args(genv, start_rest, end_rest)

        @f_args.req_positionals.each_with_index do |var, i|
          if i < start_rest
            changes.add_edge(a_args.positionals[i], @f_arg_vtxs[var])
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(vtx, @f_arg_vtxs[var])
            end
          end
        end
        @f_args.opt_positionals.each_with_index do |var, i|
          i += @f_args.opt_positionals.size
          if i < start_rest
            changes.add_edge(a_args.positionals[i], @f_arg_vtxs[var])
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(vtx, @f_arg_vtxs[var])
            end
          end
        end
        @f_args.post_positionals.each_with_index do |var, i|
          i += a_args.positionals.size - @f_args.post_positionals.size
          if end_rest <= i
            changes.add_edge(a_args.positionals[i], @f_arg_vtxs[var])
          else
            rest_vtxs.each do |vtx|
              changes.add_edge(vtx, @f_arg_vtxs[var])
            end
          end
        end

        if @f_args.rest_positionals
          rest_vtxs.each do |vtx|
            changes.add_edge(vtx, @f_arg_vtxs[@f_args.rest_positionals])
          end
        end
      else
        # there is no splat actual argument

        lower = @f_args.req_positionals.size + @f_args.post_positionals.size
        upper = @f_args.rest_positionals ? nil : lower + @f_args.opt_positionals.size
        if a_args.positionals.size < lower || (upper && upper < a_args.positionals.size)
          if call_node
            meth = call_node.mid_code_range ? :mid_code_range : :code_range
            err = "#{ a_args.positionals.size } for #{ lower }#{ upper ? lower < upper ? "...#{ upper }" : "" : "+" }"
            changes.add_diagnostic(
              TypeProf::Diagnostic.new(call_node, meth, "wrong number of arguments (#{ err })")
            )
          end
          return false
        end

        @f_args.req_positionals.each_with_index do |var, i|
          changes.add_edge(a_args.positionals[i], @f_arg_vtxs[var])
        end
        @f_args.post_positionals.each_with_index do |var, i|
          i -= @f_args.post_positionals.size
          changes.add_edge(a_args.positionals[i], @f_arg_vtxs[var])
        end
        start_rest = @f_args.req_positionals.size
        end_rest = a_args.positionals.size - @f_args.post_positionals.size
        i = 0
        while i < @f_args.opt_positionals.size && start_rest < end_rest
          f_arg = @f_arg_vtxs[@f_args.opt_positionals[i]]
          changes.add_edge(a_args.positionals[start_rest], f_arg)
          i += 1
          start_rest += 1
        end

        if start_rest < end_rest
          if @f_args.rest_positionals
            f_arg = @f_arg_vtxs[@f_args.rest_positionals]
            (start_rest..end_rest-1).each do |i|
              changes.add_edge(a_args.positionals[i], f_arg)
            end
          end
        end
      end
      return true
    end

    def call(changes, genv, call_node, a_args, ret)
      if pass_positionals(changes, genv, call_node, a_args)
        changes.add_edge(a_args.block, @block) if @block && a_args.block

        changes.add_edge(@ret, ret)
      end
    end

    def show
      block_show = []
      if @block
        # TODO: record what are yielded, not what the blocks accepted
        @block.types.each_key do |ty|
          case ty
          when Type::Proc
            block_show << "{ (#{ ty.block.f_args.map {|arg| arg.show }.join(", ") }) -> #{ ty.block.ret.show } }"
          else
            puts "???"
          end
        end
      end
      args = []
      @f_args.req_positionals.each do |var|
        args << Type.strip_parens(@f_arg_vtxs[var].show)
      end
      @f_args.opt_positionals.each do |var|
        args << ("?" + Type.strip_parens(@f_arg_vtxs[var].show))
      end
      if @f_args.rest_positionals
        args << ("*" + Type.strip_parens(@f_arg_vtxs[@f_args.rest_positionals].show))
      end
      @f_args.post_positionals.each do |var|
        args << Type.strip_parens(@f_arg_vtxs[var].show)
      end
      # TODO: keywords
      args = args.join(", ")
      s = args.empty? ? [] : ["(#{ args })"]
      s << "#{ block_show.sort.join(" | ") }" unless block_show.empty?
      s << "-> #{ @ret.show }"
      s.join(" ")
    end
  end

  class CallSite < Site
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
      resolve(genv, changes) do |recv_ty, mid, me, param_map|
        if !me
          # TODO: undefined method error
          if error_count < 3
            meth = @node.mid_code_range ? :mid_code_range : :code_range
            changes.add_diagnostic(
              TypeProf::Diagnostic.new(@node, meth, "undefined method: #{ recv_ty.show }##{ mid }")
            )
          end
          error_count += 1
        elsif me.builtin
          # TODO: block? diagnostics?
          me.builtin[changes, @node, recv_ty, @a_args, @ret]
        elsif !me.decls.empty?
          # TODO: support "| ..."
          me.decls.each do |mdecl|
            # TODO: union type is ok?
            # TODO: add_depended_method_entities for types used to resolve overloads
            mdecl.resolve_overloads(changes, genv, @node, param_map, @a_args, @ret)
          end
        elsif !me.defs.empty?
          me.defs.each do |mdef|
            next if called_mdefs.include?(mdef)
            called_mdefs << mdef
            mdef.call(changes, genv, @node, @a_args, @ret)
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
              mdef.call(changes, genv, @node, @a_args, @ret)
            end
          end
        end
      end
      edges.each do |src, dst|
        changes.add_edge(src, dst)
      end
      if error_count > 3
        meth = @node.mid_code_range ? :mid_code_range : :code_range
        changes.add_diagnostic(
          TypeProf::Diagnostic.new(@node, meth, "... and other #{ error_count - 3 } errors")
        )
      end
    end

    def resolve(genv, changes, &blk)
      @recv.types.each do |ty, _source|
        next if ty == Type::Bot.new(genv)
        if @mid == :"*super"
          mid = @node.lenv.cref.mid
          skip = true
        else
          mid = @mid
          skip = false
        end
        base_ty = ty.base_type(genv)
        mod = base_ty.mod
        param_map = Type.default_param_map(genv, ty)
        if base_ty.is_a?(Type::Instance)
          if mod.type_params
            mod.type_params.zip(base_ty.args) do |k, v|
              param_map[k] = v
            end
          end
        end
        singleton = base_ty.is_a?(Type::Singleton)
        # TODO: resolution for module
        while mod
          # pp [mod, singleton]
          unless skip
            me = mod.get_method(singleton, mid)
            changes.add_depended_method_entities(me) if changes
            if !me.aliases.empty?
              mid = me.aliases.values.first
              redo
            end
            if me && me.exist?
              yield ty, mid, me, param_map
              break
            end
          end

          skip = false

          unless singleton
            break if resolve_included_modules(genv, changes, ty, mod, singleton, mid, param_map, &blk)
          end

          type_args = mod.superclass_type_args
          mod, singleton = genv.get_superclass(mod, singleton)
          if mod && mod.type_params
            param_map2 = Type.default_param_map(genv, ty)
            # annotate                   vvvvvv
            mod.type_params.zip(type_args || []) do |param, arg|
              param_map2[param] = arg ? arg.covariant_vertex(genv, changes, param_map) : Source.new
            end
            param_map = param_map2
          end
        end

        yield ty, mid, nil, param_map unless mod
      end
    end

    def resolve_included_modules(genv, changes, ty, mod, singleton, mid, param_map, &blk)
      found = false

      mod.included_modules.each do |inc_decl, inc_mod|
        param_map2 = Type.default_param_map(genv, ty)
        if inc_decl.is_a?(AST::SIG_INCLUDE) && inc_mod.type_params
          inc_mod.type_params.zip(inc_decl.args || []) do |param, arg|
            param_map2[param] = arg && changes ? arg.covariant_vertex(genv, changes, param_map) : Source.new
          end
        end

        me = inc_mod.get_method(singleton, mid)
        changes.add_depended_method_entities(me) if changes
        if !me.aliases.empty?
          mid = me.aliases.values.first
          redo
        end
        if me.exist?
          found = true
          yield ty, mid, me, param_map2
        else
          found ||= resolve_included_modules(genv, changes, ty, inc_mod, singleton, mid, param_map2, &blk)
        end
      end
      found
    end

    def resolve_subclasses(genv, changes)
      # TODO: This does not follow new subclasses
      @recv.types.each do |ty, _source|
        next if ty == Type::Bot.new(genv)
        base_ty = ty.base_type(genv)
        singleton = base_ty.is_a?(Type::Singleton)
        mod = base_ty.mod
        mod.each_descendant do |desc_mod|
          next if mod == desc_mod
          me = desc_mod.get_method(singleton, @mid)
          changes.add_depended_method_entities(me)
          if me && me.exist?
            yield ty, me
          end
        end
      end
    end

    def long_inspect
      "#{ to_s } (mid:#{ @mid } @ #{ @node.code_range })"
    end
  end

  class GVarReadSite < Site
    def initialize(node, genv, name)
      super(node)
      @vtx = genv.resolve_gvar(name).vtx
      @ret = Vertex.new("gvar", node)
      genv.add_run(self)
    end

    attr_reader :node, :const_read, :ret

    def run0(genv, changes)
      changes.add_edge(@vtx, @ret)
    end

    def long_inspect
      "TODO"
    end
  end

  class IVarReadSite < Site
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
      while mod
        ive = mod.get_ivar(singleton, @name)
        if ive.exist?
          target_vtx = ive.vtx
        end
        mod, singleton = genv.get_superclass(mod, singleton)
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
        changes.add_edge(src, dst)
      end
    end

    def long_inspect
      "IVarTODO"
    end
  end

  class MAsgnSite < Site
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
      @rhs.types.each do |ty, _source|
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
        changes.add_edge(src, dst)
      end
    end

    def long_inspect
      "#{ to_s } (masgn)"
    end
  end
end