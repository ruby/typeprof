module TypeProfiler
  class CRef
    include Utils::StructuralEquality

    def initialize(outer, klass, singleton)
      @outer = outer
      @klass = klass
      @singleton = singleton
      # flags
      # scope_visi (= method_visi * module_func_flag)
      # refinements
    end

    def extend(klass, singleton)
      CRef.new(self, klass, singleton)
    end

    attr_reader :outer, :klass, :singleton

    def pretty_print(q)
      q.text "CRef["
      q.pp @klass
      q.text "]"
    end
  end

  class Context
    include Utils::StructuralEquality

    def initialize(iseq, cref, mid)
      @iseq = iseq
      @cref = cref
      @mid = mid
    end

    attr_reader :iseq, :cref, :mid
  end

  class TypedContext
    include Utils::StructuralEquality

    def initialize(caller_ep, mid)
      @caller_ep = caller_ep
      @mid = mid
    end

    attr_reader :caller_ep, :mid
  end

  class ExecutionPoint
    include Utils::StructuralEquality

    def initialize(ctx, pc, outer)
      @ctx = ctx
      @pc = pc
      @outer = outer
    end

    def key
      [@ctx.iseq, @pc]
    end

    attr_reader :ctx, :pc, :outer

    def jump(pc)
      ExecutionPoint.new(@ctx, pc, @outer)
    end

    def next
      ExecutionPoint.new(@ctx, @pc + 1, @outer)
    end

    def source_location
      iseq = @ctx.iseq
      if iseq
        iseq.source_location(@pc)
      else
        "<builtin>"
      end
    end
  end

  class StaticEnv
    include Utils::StructuralEquality

    def initialize(recv_ty, blk_ty, mod_func)
      @recv_ty = recv_ty
      @blk_ty = blk_ty
      @mod_func = mod_func
    end

    attr_reader :recv_ty, :blk_ty, :mod_func

    def merge(other)
      recv_ty = @recv_ty.union(other.recv_ty)
      blk_ty = @blk_ty.union(other.blk_ty)
      mod_func = @mod_func & other.mod_func # ??
      StaticEnv.new(recv_ty, blk_ty, mod_func)
    end
  end

  class Env
    include Utils::StructuralEquality

    def initialize(static_env, locals, stack, type_params)
      @static_env = static_env
      @locals = locals
      @stack = stack
      @type_params = type_params
    end

    attr_reader :static_env, :locals, :stack, :type_params

    def merge(other)
      raise if @locals.size != other.locals.size
      raise if @stack.size != other.stack.size
      static_env = @static_env.merge(other.static_env)
      locals = []
      @locals.zip(other.locals) {|ty1, ty2| locals << ty1.union(ty2) }
      stack = []
      @stack.zip(other.stack) {|ty1, ty2| stack << ty1.union(ty2) }
      if @type_params
        raise if !other.type_params
        if @type_params == other.type_params
          type_params = @type_params
        else
          type_params = @type_params.internal_hash.dup
          other.type_params.internal_hash.each do |id, elems|
            elems2 = type_params[id]
            if elems2
              type_params[id] = elems.union(elems2) if elems != elems2
            else
              type_params[id] = elems
            end
          end
          type_params = Utils::HashWrapper.new(type_params)
        end
      else
        raise if other.type_params
      end
      Env.new(static_env, locals, stack, type_params)
    end

    def push(*tys)
      tys.each do |ty|
        raise "nil cannot be pushed to the stack" if ty.nil?
        ty.each_child do |ty|
          raise "Array cannot be pushed to the stack" if ty.is_a?(Type::Array)
          raise "Hash cannot be pushed to the stack" if ty.is_a?(Type::Hash)
        end
      end
      Env.new(@static_env, @locals, @stack + tys, @type_params)
    end

    def pop(n)
      stack = @stack.dup
      tys = stack.pop(n)
      nenv = Env.new(@static_env, @locals, stack, @type_params)
      return nenv, tys
    end

    def setn(i, ty)
      stack = Utils.array_update(@stack, -i, ty)
      Env.new(@static_env, @locals, stack, @type_params)
    end

    def topn(i)
      push(@stack[-i - 1])
    end

    def get_local(idx)
      @locals[idx]
    end

    def local_update(idx, ty)
      Env.new(@static_env, Utils.array_update(@locals, idx, ty), @stack, @type_params)
    end

    def deploy_array_type(alloc_site, elems, base_ty)
      local_ty = Type::LocalArray.new(alloc_site, base_ty)
      type_params = Utils::HashWrapper.new(@type_params.internal_hash.merge({ alloc_site => elems }))
      nenv = Env.new(@static_env, @locals, @stack, type_params)
      return nenv, local_ty
    end

    def deploy_hash_type(alloc_site, elems, base_ty)
      local_ty = Type::LocalHash.new(alloc_site, base_ty)
      type_params = Utils::HashWrapper.new(@type_params.internal_hash.merge({ alloc_site => elems }))
      nenv = Env.new(@static_env, @locals, @stack, type_params)
      return nenv, local_ty
    end

    def get_container_elem_types(id)
      @type_params.internal_hash[id]
    end

    def update_container_elem_types(id, elems)
      type_params = Utils::HashWrapper.new(@type_params.internal_hash.merge({ id => elems }))
      Env.new(@static_env, @locals, @stack, type_params)
    end

    def enable_module_function
      senv = StaticEnv.new(@static_env.recv_ty, @static_env.blk_ty, true)
      Env.new(senv, @locals, @stack, @type_params)
    end

    def replace_recv_ty(ty)
      senv = StaticEnv.new(ty, @static_env.blk_ty, @static_env.mod_func)
      Env.new(senv, @locals, @stack, @type_params)
    end

    def inspect
      "Env[#{ @static_env.inspect }, locals:#{ @locals.inspect }, stack:#{ @stack.inspect }, type_params:#{ (@type_params&.internal_hash).inspect }]"
    end
  end

  class Scratch
    def inspect
      "#<Scratch>"
    end

    def initialize
      @worklist = Utils::WorkList.new

      @ep2env = {}

      @class_defs = {}
      @struct_defs = {}

      @iseq_method_to_ctxs = {}

      @alloc_site_to_global_id = {}

      @callsites, @return_envs, @sig_fargs, @sig_ret, @yields = {}, {}, {}, {}, {}
      @block_to_ctx = {}
      @gvar_table = VarTable.new

      @include_relations = {}

      @errors = []
      @reveal_types = {}
      @backward_edges = {}

      @pending_execution = {}
      @executed_iseqs = Utils::MutableSet.new

      @loaded_features = {}

      @rbs_reader = RBSReader.new
    end

    attr_reader :return_envs, :loaded_features, :rbs_reader

    def get_env(ep)
      @ep2env[ep]
    end

    def merge_env(ep, env)
      # TODO: this is wrong; it include not only proceeds but also indirect propagation like out-of-block variable modification
      #add_edge(ep, @ep)
      env2 = @ep2env[ep]
      if env2
        nenv = env2.merge(env)
        if !nenv.eql?(env2) && !@worklist.member?(ep)
          @worklist.insert(ep.key, ep)
        end
        @ep2env[ep] = nenv
      else
        @worklist.insert(ep.key, ep)
        @ep2env[ep] = env
      end
    end

    attr_reader :class_defs

    class ClassDef # or ModuleDef
      def initialize(kind, name, superclass)
        @kind = kind
        @superclass = superclass
        @modules = { true => [], false => [] }
        @name = name
        @consts = {}
        @methods = {}
        @ivars = VarTable.new
        @cvars = VarTable.new
      end

      attr_reader :kind, :modules, :methods, :superclass, :ivars, :cvars
      attr_accessor :name, :klass_obj

      def include_module(mod, visible)
        # XXX: need to check if mod is already included by the ancestors?
        unless @modules[false].include?([visible, mod])
          @modules[false] << [visible, mod]
        end
      end

      def extend_module(mod, visible)
        # XXX: need to check if mod is already included by the ancestors?
        unless @modules[true].include?([visible, mod])
          @modules[true] << [visible, mod]
        end
      end

      def get_constant(name)
        @consts[name] || Type.any # XXX: warn?
      end

      def add_constant(name, ty)
        if @consts[name]
          # XXX: warn!
        end
        @consts[name] = ty
      end

      def get_method(mid, singleton)
        @methods[[singleton, mid]] || begin
          @modules[singleton].reverse_each do |_visible, mod|
            meth = mod.get_method(mid, false)
            return meth if meth
          end
          nil
        end
      end

      def check_typed_method(mid, singleton)
        set = @methods[[singleton, mid]]
        return nil unless set
        set = set.select {|mdef| mdef.is_a?(TypedMethodDef) }
        return nil if set.empty?
        return set
      end

      def add_method(mid, singleton, mdef)
        @methods[[singleton, mid]] ||= Utils::MutableSet.new
        @methods[[singleton, mid]] << mdef
        # Need to restart...?
      end
    end

    def include_module(including_mod, included_mod, visible = true)
      return if included_mod == Type.any

      if visible
        @include_relations[including_mod] ||= Utils::MutableSet.new
        @include_relations[including_mod] << included_mod
      end

      including_mod = @class_defs[including_mod.idx]
      included_mod.each_child do |included_mod|
        if included_mod.is_a?(Type::Class)
          included_mod = @class_defs[included_mod.idx]
          if included_mod && included_mod.kind == :module
            including_mod.include_module(included_mod, visible)
          else
            warn "including something that is not a module"
          end
        end
      end
    end

    def extend_module(extending_mod, extended_mod, visible = true)
      extending_mod = @class_defs[extending_mod.idx]
      extended_mod.each_child do |extended_mod|
        if extended_mod.is_a?(Type::Class)
          extended_mod = @class_defs[extended_mod.idx]
          if extended_mod && extended_mod.kind == :module
            extending_mod.extend_module(extended_mod, visible)
          else
            warn "extending something that is not a module"
          end
        end
      end
    end

    def new_class(cbase, name, type_params, superclass)
      if cbase && cbase.idx != 0
        show_name = "#{ @class_defs[cbase.idx].name }::#{ name }"
      else
        show_name = name.to_s
      end
      idx = @class_defs.size
      if superclass
        if superclass == :__root__
          superclass_idx = superclass = nil
        else
          superclass_idx = superclass.idx
        end
        @class_defs[idx] = ClassDef.new(:class, show_name, superclass_idx)
        klass = Type::Class.new(:class, idx, type_params, superclass, show_name)
        @class_defs[idx].klass_obj = klass
        cbase ||= klass # for bootstrap
        add_constant(cbase, name, klass)
        return klass
      else
        # module
        @class_defs[idx] = ClassDef.new(:module, show_name, nil)
        mod = Type::Class.new(:module, idx, type_params, nil, show_name)
        @class_defs[idx].klass_obj = mod
        add_constant(cbase, name, mod)
        return mod
      end
    end

    def new_struct(ep)
      return @struct_defs[ep] if @struct_defs[ep]

      idx = @class_defs.size
      superclass = Type::Builtin[:struct]
      @class_defs[idx] = ClassDef.new(:class, "(Struct)", superclass.idx)
      klass = Type::Class.new(:class, idx, [], superclass, "(Struct)")
      @class_defs[idx].klass_obj = klass

      @struct_defs[ep] = klass

      klass
    end

    def get_class_name(klass)
      if klass == Type.any
        "???"
      else
        @class_defs[klass.idx].name
      end
    end

    def get_method(klass, singleton, mid)
      idx = klass.idx
      while idx
        class_def = @class_defs[idx]
        mthd = class_def.get_method(mid, singleton)
        # Need to be conservative to include all super candidates...?
        return mthd if mthd
        idx = class_def.superclass
      end
      return get_method(Type::Builtin[:class], false, mid) if singleton
      nil
    end

    def get_super_method(ctx, singleton)
      idx = ctx.cref.klass.idx
      mid = ctx.mid
      idx = @class_defs[idx].superclass
      while idx
        class_def = @class_defs[idx]
        mthd = class_def.get_method(mid, singleton)
        return mthd if mthd
        idx = class_def.superclass
      end
      nil
    end

    def get_constant(klass, name)
      if klass == Type.any
        Type.any
      elsif klass.is_a?(Type::Class)
        @class_defs[klass.idx].get_constant(name)
      else
        Type.any
      end
    end

    def search_constant(cref, name)
      while cref != :bottom
        val = get_constant(cref.klass, name)
        return val if val != Type.any
        cref = cref.outer
      end

      Type.any
    end

    def add_constant(klass, name, value)
      if klass == Type.any
        self
      else
        @class_defs[klass.idx].add_constant(name, value)
      end
    end

    def check_typed_method(klass, mid, singleton)
      @class_defs[klass.idx].check_typed_method(mid, singleton)
    end

    def add_method(klass, mid, singleton, mdef)
      @class_defs[klass.idx].add_method(mid, singleton, mdef)
      mdef
    end

    def add_attr_method(klass, mid, ivar, kind)
      if kind == :reader || kind == :accessor
        add_method(klass, mid, false, AttrMethodDef.new(ivar, :reader))
      end
      if kind == :writer || kind == :accessor
        add_method(klass, :"#{ mid }=", false, AttrMethodDef.new(ivar, :writer))
      end
    end

    def add_iseq_method(klass, mid, iseq, cref)
      add_method(klass, mid, false, ISeqMethodDef.new(iseq, cref))
    end

    def add_singleton_iseq_method(klass, mid, iseq, cref)
      add_method(klass, mid, true, ISeqMethodDef.new(iseq, cref))
    end

    def add_typed_method(recv_ty, mid, fargs, ret_ty)
      add_method(recv_ty.klass, mid, false, TypedMethodDef.new([[fargs, ret_ty]]))
    end

    def add_singleton_typed_method(recv_ty, mid, fargs, ret_ty)
      add_method(recv_ty.klass, mid, true, TypedMethodDef.new([[fargs, ret_ty]]))
    end

    def add_custom_method(klass, mid, impl)
      add_method(klass, mid, false, CustomMethodDef.new(impl))
    end

    def add_singleton_custom_method(klass, mid, impl)
      add_method(klass, mid, true, CustomMethodDef.new(impl))
    end

    def alias_method(klass, singleton, new, old)
      if klass == Type.any
        self
      else
        mdefs = get_method(klass, singleton, old)
        if mdefs
          mdefs.each do |mdef|
            @class_defs[klass.idx].add_method(new, singleton, mdef)
          end
        end
      end
    end

    def add_edge(ep, next_ep)
      (@backward_edges[next_ep] ||= {})[ep] = true
    end

    def add_iseq_method_call!(iseq_mdef, ctx)
      @iseq_method_to_ctxs[iseq_mdef] ||= Utils::MutableSet.new
      @iseq_method_to_ctxs[iseq_mdef] << ctx
    end

    def add_callsite!(callee_ctx, fargs, caller_ep, caller_env, &ctn)
      @executed_iseqs << callee_ctx.iseq if callee_ctx.is_a?(Context)

      @callsites[callee_ctx] ||= {}
      @callsites[callee_ctx][caller_ep] = ctn
      merge_return_env(caller_ep) {|env| env ? env.merge(caller_env) : caller_env }

      if @sig_fargs[callee_ctx]
        @sig_fargs[callee_ctx] = @sig_fargs[callee_ctx].merge(fargs)
      else
        @sig_fargs[callee_ctx] = fargs
      end
      ret_ty = @sig_ret[callee_ctx] ||= Type.bot
      unless ret_ty.eql?(Type.bot)
        @callsites[callee_ctx].each do |caller_ep, ctn|
          ctn[ret_ty, caller_ep, @return_envs[caller_ep]]
        end
      end
    end

    def merge_return_env(caller_ep)
      @return_envs[caller_ep] = yield @return_envs[caller_ep]
    end

    def add_return_type!(callee_ctx, ret_ty)
      @sig_ret[callee_ctx] ||= Type.bot
      @sig_ret[callee_ctx] = @sig_ret[callee_ctx].union(ret_ty)

      @callsites[callee_ctx] ||= {}
      @callsites[callee_ctx].each do |caller_ep, ctn|
        ctn[ret_ty, caller_ep, @return_envs[caller_ep]]
      end
    end

    def add_yield!(caller_ctx, aargs, blk_ctx)
      aargs_acc, = @yields[caller_ctx]
      if aargs_acc
        @yields[caller_ctx][0] = aargs_acc.merge(aargs)
      else
        @yields[caller_ctx] = [aargs, Utils::MutableSet.new]
      end
      @yields[caller_ctx][1] << blk_ctx
    end

    def add_block_to_ctx!(blk, ctx)
      @block_to_ctx[blk] ||= Utils::MutableSet.new
      @block_to_ctx[blk] << ctx
    end

    class VarTable
      def initialize
        @read, @write = {}, {}
      end

      attr_reader :write

      def add_read!(site, ep, &ctn)
        @read[site] ||= {}
        @read[site][ep] = ctn
        @write[site] ||= Type.bot
        ctn[@write[site], ep]
      end

      def add_write!(site, ty, &ctn)
        @write[site] ||= Type.bot
        @write[site] = @write[site].union(ty)
        @read[site] ||= {}
        @read[site].each do |ep, ctn|
          ctn[ty, ep]
        end
      end
    end

    def get_ivar(recv)
      case recv
      when Type::Class
        [@class_defs[recv.idx], true]
      when Type::Instance
        [@class_defs[recv.klass.idx], false]
      when Type::Any
        return
      else
        warn "???"
        return
      end
    end

    def add_ivar_read!(recv, var, ep, &ctn)
      recv.each_child do |recv|
        class_def, singleton = get_ivar(recv)
        next unless class_def
        class_def.ivars.add_read!([singleton, var], ep, &ctn)
      end
    end

    def add_ivar_write!(recv, var, ty, &ctn)
      recv.each_child do |recv|
        class_def, singleton = get_ivar(recv)
        next unless class_def
        class_def.ivars.add_write!([singleton, var], ty, &ctn)
      end
    end

    def add_cvar_read!(klass, var, ep, &ctn)
      klass.each_child do |klass|
        class_def = @class_defs[klass.idx]
        next unless class_def
        class_def.cvars.add_read!(var, ep, &ctn)
      end
    end

    def add_cvar_write!(klass, var, ty, &ctn)
      klass.each_child do |klass|
        class_def = @class_defs[klass.idx]
        next unless class_def
        class_def.cvars.add_write!(var, ty, &ctn)
      end
    end

    def add_gvar_read!(var, ep, &ctn)
      @gvar_table.add_read!(var, ep, &ctn)
    end

    def add_gvar_write!(var, ty, &ctn)
      @gvar_table.add_write!(var, ty, &ctn)
    end

    def error(ep, msg)
      p [ep.source_location, "[error] " + msg] if ENV["TP_DEBUG"]
      @errors << [ep, "[error] " + msg]
    end

    def warn(ep, msg)
      p [ep.source_location, "[warning] " + msg] if ENV["TP_DEBUG"]
      @errors << [ep, "[warning] " + msg]
    end

    def reveal_type(ep, ty)
      key = ep.source_location
      puts "reveal:#{ ep.source_location }:#{ ty.screen_name(self) }" if ENV["TP_DEBUG"]
      if @reveal_types[key]
        @reveal_types[key] = @reveal_types[key].union(ty)
      else
        @reveal_types[key] = ty
      end
    end

    def get_container_elem_types(env, ep, id)
      if ep.outer
        tmp_ep = ep
        tmp_ep = tmp_ep.outer while tmp_ep.outer
        env = @return_envs[tmp_ep]
      end
      env.get_container_elem_types(id)
    end

    def update_container_elem_types(env, ep, id)
      if ep.outer
        tmp_ep = ep
        tmp_ep = tmp_ep.outer while tmp_ep.outer
        merge_return_env(tmp_ep) do |menv|
          elems = menv.get_container_elem_types(id)
          elems = yield elems
          menv = menv.update_container_elem_types(id, elems)
          gid = @alloc_site_to_global_id[id]
          if gid
            ty = globalize_type(elems.to_local_type(id), env, ep)
            add_ivar_write!(*gid, ty)
          end
          menv
        end
        env
      else
        elems = env.get_container_elem_types(id)
        elems = yield elems
        env = env.update_container_elem_types(id, elems)
        gid = @alloc_site_to_global_id[id]
        if gid
          ty = globalize_type(elems.to_local_type(id), env, ep)
          add_ivar_write!(*gid, ty)
        end
        env
      end
    end

    def get_array_elem_type(env, ep, id, idx = nil)
      elems = get_container_elem_types(env, ep, id)

      if elems
        return elems[idx] || Type.nil if idx
        return elems.squash
      else
        Type.any
      end
    end

    def get_hash_elem_type(env, ep, id, key_ty = nil)
      elems = get_container_elem_types(env, ep, id)

      if elems
        elems[globalize_type(key_ty, env, ep) || Type.any]
      else
        Type.any
      end
    end

    def type_profile
      counter = 0
      stat_eps = Utils::MutableSet.new
      while true
        until @worklist.empty?
          counter += 1
          if counter % 1000 == 0
            puts "iter %d, remain: %d" % [counter, @worklist.size]
            #exit if counter == 20000
          end
          @ep = @worklist.deletemin
          stat_eps << @ep
          step(@ep) # TODO: deletemin
        end

        # XXX: it would be good to provide no-dummy-execution mode.
        # It should work as a bit smarter "rbs prototype rb";
        # show all method definitions as "untyped" arguments and return values

        begin
          iseq, (kind, dummy_continuation) = @pending_execution.first
          break if !iseq
          @pending_execution.delete(iseq)
        end while @executed_iseqs.include?(iseq)

        puts "DEBUG: trigger dummy execution (#{ iseq&.name || "(nil)" }): rest #{ @pending_execution.size }" if ENV["TP_DEBUG"]

        break if !iseq
        case kind
        when :method
          meth, ep, env = dummy_continuation
          merge_env(ep, env)
          add_iseq_method_call!(meth, ep.ctx)

          fargs_format = iseq.fargs_format
          lead_tys = [Type.any] * (fargs_format[:lead_num] || 0)
          opt_tys = fargs_format[:opt] ? [] : nil
          post_tys = [Type.any] * (fargs_format[:post_num] || 0)
          if fargs_format[:kwbits]
            kw_tys = []
            fargs_format[:keyword].each do |kw|
              case
              when kw.is_a?(Symbol) # required keyword
                key = kw
                req = true
                ty = Type.any
              when kw.size == 2 # optional keyword (default value is a literal)
                key, ty = *kw
                ty = Type.guess_literal_type(ty)
                ty = ty.type if ty.is_a?(Type::Literal)
              else # optional keyword
                key, = kw
                req = false
                ty = Type.any
              end
              kw_tys << [req, key, ty]
            end
          else
            kw_tys = nil
          end
          fargs = FormalArguments.new(lead_tys, opt_tys, nil, post_tys, kw_tys, nil, nil)
          add_callsite!(ep.ctx, fargs, nil, nil) do |_ret_ty, _ep, _env|
            # ignore
          end

        when :block
          epenvs = dummy_continuation
          epenvs.each do |ep, env|
            merge_env(ep, env)
          end
        end
      end

      report(stat_eps)
    end

    def report(stat_eps)
      Reporters.show_error(@errors, @backward_edges)

      Reporters.show_reveal_types(self, @reveal_types)

      Reporters.show_gvars(self, @gvar_table.write)

      #RubySignatureExporter2.new(
      #  self, @include_relations, @ivar_table.write, @cvar_table.write, @class_defs
      #).show

      #return
      RubySignatureExporter.new(self, @class_defs, @iseq_method_to_ctxs, @sig_fargs, @sig_ret, @yields).show(stat_eps)
    end

    def globalize_type(ty, env, ep)
      if ep.outer
        tmp_ep = ep
        tmp_ep = tmp_ep.outer while tmp_ep.outer
        env = @return_envs[tmp_ep]
      end
      ty.globalize(env, {}, $TYPE_DEPTH_LIMIT)
    end

    def localize_type(ty, env, ep, alloc_site = AllocationSite.new(ep))
      if ep.outer
        tmp_ep = ep
        tmp_ep = tmp_ep.outer while tmp_ep.outer
        target_env = @return_envs[tmp_ep]
        target_env, ty = ty.localize(target_env, alloc_site, $TYPE_DEPTH_LIMIT)
        merge_return_env(tmp_ep) do |env|
          env ? env.merge(target_env) : target_env
        end
        return env, ty
      else
        return ty.localize(env, alloc_site, $TYPE_DEPTH_LIMIT)
      end
    end

    def pend_method_execution(iseq, meth, recv, mid, cref)
      ctx = Context.new(iseq, cref, mid)
      ep = ExecutionPoint.new(ctx, 0, nil)
      locals = [Type.any] * iseq.locals.size
      env = Env.new(StaticEnv.new(recv, Type.any, false), locals, [], Utils::HashWrapper.new({}))

      @pending_execution[iseq] ||= [:method, [meth, ep, env]]
    end

    def pend_block_dummy_execution(iseq, nep, nenv)
      @pending_execution[iseq] ||= [:block, {}]
      if @pending_execution[iseq][1][nep]
        @pending_execution[iseq][1][nep] = @pending_execution[iseq][1][nep].merge(nenv)
      else
        @pending_execution[iseq][1][nep] = nenv
      end
    end

    def get_instance_variable(recv, var, ep, env)
      add_ivar_read!(recv, var, ep) do |ty, ep|
        alloc_site = AllocationSite.new(ep)
        nenv, ty = localize_type(ty, env, ep, alloc_site)
        case ty
        when Type::LocalArray, Type::LocalHash
          @alloc_site_to_global_id[ty.id] = [recv, var] # need overwrite check??
        end
        yield ty, nenv
      end
    end

    def set_instance_variable(recv, var, ty, ep, env)
      ty = globalize_type(ty, env, ep)
      add_ivar_write!(recv, var, ty)
    end

    def step(ep)
      orig_ep = ep
      env = @ep2env[ep]
      raise "nil env" unless env

      insn, operands = ep.ctx.iseq.insns[ep.pc]

      if ENV["TP_DEBUG"]
        puts "DEBUG: stack=%p" % [env.stack]
        puts "DEBUG: %s (%s) PC=%d insn=%s sp=%d" % [ep.source_location, ep.ctx.iseq.name, ep.pc, insn, env.stack.size]
      end

      case insn
      when :putspecialobject
        kind, = operands
        ty = case kind
        when 1 then Type::Instance.new(Type::Builtin[:vmcore])
        when 2, 3 # CBASE / CONSTBASE
          ep.ctx.cref.klass
        else
          raise NotImplementedError, "unknown special object: #{ type }"
        end
        env = env.push(ty)
      when :putnil
        env = env.push(Type.nil)
      when :putobject, :duparray
        obj, = operands
        env, ty = localize_type(Type.guess_literal_type(obj), env, ep)
        env = env.push(ty)
      when :putstring
        str, = operands
        ty = Type::Literal.new(str, Type::Instance.new(Type::Builtin[:str]))
        env = env.push(ty)
      when :putself
        env, ty = localize_type(env.static_env.recv_ty, env, ep)
        env = env.push(ty)
      when :newarray, :newarraykwsplat
        len, = operands
        env, elems = env.pop(len)
        ty = Type::Array.new(Type::Array::Elements.new(elems), Type::Instance.new(Type::Builtin[:ary]))
        env, ty = localize_type(ty, env, ep)
        env = env.push(ty)
      when :newhash
        num, = operands
        env, tys = env.pop(num)

        ty = Type.gen_hash do |h|
          tys.each_slice(2) do |k_ty, v_ty|
            k_ty = globalize_type(k_ty, env, ep)
            h[k_ty] = v_ty
          end
        end

        env, ty = localize_type(ty, env, ep)
        env = env.push(ty)
      when :newhashfromarray
        raise NotImplementedError, "newhashfromarray"
      when :newrange
        env, tys = env.pop(2)
        # XXX: need generics
        env = env.push(Type::Instance.new(Type::Builtin[:range]))

      when :concatstrings
        num, = operands
        env, = env.pop(num)
        env = env.push(Type::Instance.new(Type::Builtin[:str]))
      when :tostring
        env, (_ty1, _ty2,) = env.pop(2)
        env = env.push(Type::Instance.new(Type::Builtin[:str]))
      when :freezestring
        # do nothing
      when :toregexp
        _regexp_opt, str_count = operands
        env, tys = env.pop(str_count)
        # TODO: check if tys are all strings?
        env = env.push(Type::Instance.new(Type::Builtin[:regexp]))
      when :intern
        env, (ty,) = env.pop(1)
        # XXX check if ty is String
        env = env.push(Type::Instance.new(Type::Builtin[:sym]))

      when :definemethod
        mid, iseq = operands
        cref = ep.ctx.cref
        recv = env.static_env.recv_ty
        if cref.klass.is_a?(Type::Class)
          typed_mdef = check_typed_method(cref.klass, mid, ep.ctx.cref.singleton)
          if typed_mdef
            mdef = ISeqMethodDef.new(iseq, cref)
            typed_mdef.each do |typed_mdef|
              typed_mdef.do_match_iseq_mdef(mdef, recv, mid, env, ep, self)
            end
          else
            if ep.ctx.cref.singleton
              meth = add_singleton_iseq_method(cref.klass, mid, iseq, cref)
            else
              meth = add_iseq_method(cref.klass, mid, iseq, cref)
              if env.static_env.mod_func
                add_singleton_iseq_method(cref.klass, mid, iseq, cref)
              end
            end

            recv = Type::Instance.new(recv) if recv.is_a?(Type::Class)
            pend_method_execution(iseq, meth, recv, mid, ep.ctx.cref)
          end
        else
          # XXX: what to do?
        end

      when :definesmethod
        mid, iseq = operands
        env, (recv,) = env.pop(1)
        cref = ep.ctx.cref
        recv.each_child do |recv|
          if recv.is_a?(Type::Class)
            meth = add_singleton_iseq_method(recv, mid, iseq, cref)
            pend_method_execution(iseq, meth, recv, mid, ep.ctx.cref)
          else
            recv = Type.any # XXX: what to do?
          end
        end
      when :defineclass
        id, iseq, flags = operands
        env, (cbase, superclass) = env.pop(2)
        case flags & 7
        when 0, 2 # CLASS / MODULE
          type = (flags & 7) == 2 ? :module : :class
          existing_klass = get_constant(cbase, id) # TODO: multiple return values
          if existing_klass.is_a?(Type::Class)
            klass = existing_klass
          else
            if existing_klass != Type.any
              error(ep, "the class \"#{ id }\" is #{ existing_klass.screen_name(self) }")
              id = :"#{ id }(dummy)"
            end
            existing_klass = get_constant(cbase, id) # TODO: multiple return values
            if existing_klass != Type.any
              klass = existing_klass
            else
              if type == :class
                if superclass.is_a?(Type::Class)
                  # okay
                elsif superclass == Type.any
                  warn(ep, "superclass is any; Object is used instead")
                  superclass = Type::Builtin[:obj]
                elsif superclass.eql?(Type.nil)
                  superclass = Type::Builtin[:obj]
                elsif superclass.is_a?(Type::Instance)
                  warn(ep, "superclass is an instance; Object is used instead")
                  superclass = Type::Builtin[:obj]
                else
                  warn(ep, "superclass is not a class; Object is used instead")
                  superclass = Type::Builtin[:obj]
                end
              else # module
                superclass = nil
              end
              if cbase == Type.any
                klass = Type.any
              else
                klass = new_class(cbase, id, [], superclass)
              end
            end
          end
          singleton = false
        when 1 # SINGLETON_CLASS
          singleton = true
          klass = cbase
          if klass.is_a?(Type::Class)
          elsif klass.is_a?(Type::Any)
          else
            warn(ep, "A singleton class is open for #{ klass.screen_name(self) }; handled as any")
            klass = Type.any
          end
        else
          raise NotImplementedError, "unknown defineclass flag: #{ flags }"
        end
        ncref = ep.ctx.cref.extend(klass, singleton)
        recv = singleton ? Type.any : klass
        blk = env.static_env.blk_ty
        nctx = Context.new(iseq, ncref, nil)
        nep = ExecutionPoint.new(nctx, 0, nil)
        locals = [Type.nil] * iseq.locals.size
        nenv = Env.new(StaticEnv.new(recv, blk, false), locals, [], Utils::HashWrapper.new({}))
        merge_env(nep, nenv)
        add_callsite!(nep.ctx, nil, ep, env) do |ret_ty, ep, env|
          nenv, ret_ty = localize_type(ret_ty, env, ep)
          nenv = nenv.push(ret_ty)
          merge_env(ep.next, nenv)
        end
        return
      when :send
        env, recvs, mid, aargs = setup_actual_arguments(operands, ep, env)
        recvs = Type.any if recvs == Type.bot
        recvs.each_child do |recv|
          do_send(recv, mid, aargs, ep, env) do |ret_ty, ep, env|
            nenv, ret_ty, = localize_type(ret_ty, env, ep)
            nenv = nenv.push(ret_ty)
            merge_env(ep.next, nenv)
          end
        end
        return
      when :send_branch
        getlocal_operands, send_operands, branch_operands = operands
        env, recvs, mid, aargs = setup_actual_arguments(send_operands, ep, env)
        recvs = Type.any if recvs == Type.bot
        recvs.each_child do |recv|
          do_send(recv, mid, aargs, ep, env) do |ret_ty, ep, env|
            env, ret_ty, = localize_type(ret_ty, env, ep)

            branchtype, target, = branch_operands
            # branchtype: :if or :unless or :nil
            ep_then = ep.next
            ep_else = ep.jump(target)

            var_idx, _scope_idx, _escaped = getlocal_operands
            flow_env = env.local_update(-var_idx+2, recv)

            case ret_ty
            when Type::Instance.new(Type::Builtin[:true])
              merge_env(branchtype == :if ? ep_else : ep_then, flow_env)
            when Type::Instance.new(Type::Builtin[:false])
              merge_env(branchtype == :if ? ep_then : ep_else, flow_env)
            else
              merge_env(ep_then, env)
              merge_env(ep_else, env)
            end
          end
        end
        return
      when :invokeblock
        # XXX: need block parameter, unknown block, etc.  Use setup_actual_arguments
        opt, = operands
        _flags = opt[:flag]
        orig_argc = opt[:orig_argc]
        env, aargs = env.pop(orig_argc)
        blk = env.static_env.blk_ty
        case
        when blk.eql?(Type.nil)
          env = env.push(Type.any)
        when blk.eql?(Type.any)
          #warn(ep, "block is any")
          env = env.push(Type.any)
        else # Proc
          blk_nil = Type.nil
          #
          aargs = ActualArguments.new(aargs, nil, nil, blk_nil)
          do_invoke_block(true, env.static_env.blk_ty, aargs, ep, env) do |ret_ty, ep, env|
            nenv, ret_ty, = localize_type(ret_ty, env, ep)
            nenv = nenv.push(ret_ty)
            merge_env(ep.next, nenv)
          end
          return
        end
      when :invokesuper
        env, recv, _, aargs = setup_actual_arguments(operands, ep, env)

        env, recv = localize_type(env.static_env.recv_ty, env, ep)
        mid  = ep.ctx.mid
        singleton = !recv.is_a?(Type::Instance) # TODO: any?
        # XXX: need to support included module...
        meths = get_super_method(ep.ctx, singleton) # TODO: multiple return values
        if meths
          meths.each do |meth|
            # XXX: this decomposition is really needed??
            # It calls `Object.new` with union receiver which causes an error, but
            # it may be a fault of builtin Object.new implementation.
            recv.each_child do |recv|
              meth.do_send(recv, mid, aargs, ep, env, self) do |ret_ty, ep, env|
                nenv, ret_ty, = localize_type(ret_ty, env, ep)
                nenv = nenv.push(ret_ty)
                merge_env(ep.next, nenv)
              end
            end
          end
          return
        else
          error(ep, "no superclass method: #{ env.static_env.recv_ty.screen_name(self) }##{ mid }")
          env = env.push(Type.any)
        end
      when :invokebuiltin
        raise NotImplementedError
      when :leave
        if env.stack.size != 1
          raise "stack inconsistency error: #{ env.stack.inspect }"
        end
        env, (ty,) = env.pop(1)
        ty = globalize_type(ty, env, ep)
        add_return_type!(ep.ctx, ty)
        return
      when :throw
        throwtype, = operands
        env, (ty,) = env.pop(1)
        _no_escape = !!(throwtype & 0x8000)
        throwtype = [:none, :return, :break, :next, :retry, :redo][throwtype & 0xff]
        case throwtype
        when :none

        when :return
          ty = globalize_type(ty, env, ep)
          tmp_ep = ep
          tmp_ep = tmp_ep.outer while tmp_ep.outer
          add_return_type!(tmp_ep.ctx, ty)
          return
        when :break
          tmp_ep = ep
          tmp_ep = tmp_ep.outer while tmp_ep.ctx.iseq.type != :block
          tmp_ep = tmp_ep.outer
          nenv = @return_envs[tmp_ep].push(ty)
          merge_env(tmp_ep.next, nenv)
          # TODO: jump to ensure?
        when :next, :redo
          # begin; rescue; next; end
          tmp_ep = ep.outer
          _type, _iseq, cont, stack_depth = tmp_ep.ctx.iseq.catch_table[tmp_ep.pc].find {|type,| type == throwtype }
          nenv = @return_envs[tmp_ep]
          nenv, = nenv.pop(nenv.stack.size - stack_depth)
          nenv = nenv.push(ty) if throwtype == :next
          tmp_ep = tmp_ep.jump(cont)
          merge_env(tmp_ep, nenv)
        when :retry
          tmp_ep = ep.outer
          _type, _iseq, cont, stack_depth = tmp_ep.ctx.iseq.catch_table[tmp_ep.pc].find {|type,| type == :retry }
          nenv = @return_envs[tmp_ep]
          nenv, = nenv.pop(nenv.stack.size - stack_depth)
          tmp_ep = tmp_ep.jump(cont)
          merge_env(tmp_ep, nenv)
        else
          p throwtype
          raise NotImplementedError
        end
        return
      when :once
        iseq, = operands

        nctx = Context.new(iseq, ep.ctx.cref, ep.ctx.mid)
        nep = ExecutionPoint.new(nctx, 0, ep)
        raise if iseq.locals != []
        nenv = Env.new(env.static_env, [], [], nil)
        merge_env(nep, nenv)
        add_callsite!(nep.ctx, nil, ep, env) do |ret_ty, ep, env|
          nenv, ret_ty = localize_type(ret_ty, env, ep)
          nenv = nenv.push(ret_ty)
          merge_env(ep.next, nenv)
        end
        return

      when :branch # TODO: check how branchnil is used
        branchtype, target, = operands
        # branchtype: :if or :unless or :nil
        env, (ty,) = env.pop(1)
        ep_then = ep.next
        ep_else = ep.jump(target)

        # TODO: it works for only simple cases: `x = nil; x || 1`
        # It would be good to merge "dup; branchif" to make it context-sensitive-like
        falsy = ty.eql?(Type.nil)

        merge_env(ep_then, env)
        merge_env(ep_else, env) unless branchtype == :if && falsy
        return
      when :jump
        target, = operands
        merge_env(ep.jump(target), env)
        return

      when :setinstancevariable
        var, = operands
        env, (ty,) = env.pop(1)
        recv = env.static_env.recv_ty
        set_instance_variable(recv, var, ty, ep, env)

      when :getinstancevariable
        var, = operands
        recv = env.static_env.recv_ty
        get_instance_variable(recv, var, ep, env) do |ty, nenv|
          merge_env(ep.next, nenv.push(ty))
        end
        return

      when :setclassvariable
        var, = operands
        env, (ty,) = env.pop(1)
        cbase = ep.ctx.cref.klass
        ty = globalize_type(ty, env, ep)
        # TODO: if superclass has the variable, it should be updated
        add_cvar_write!(cbase, var, ty)

      when :getclassvariable
        var, = operands
        cbase = ep.ctx.cref.klass
        # TODO: if superclass has the variable, it should be read
        add_cvar_read!(cbase, var, ep) do |ty, ep|
          nenv, ty = localize_type(ty, env, ep)
          merge_env(ep.next, nenv.push(ty))
        end
        return

      when :setglobal
        var, = operands
        env, (ty,) = env.pop(1)
        ty = globalize_type(ty, env, ep)
        add_gvar_write!(var, ty)

      when :getglobal
        var, = operands
        ty = Type.builtin_global_variable_type(var)
        if ty
          ty = get_constant(Type::Builtin[:obj], ty) if ty.is_a?(Symbol)
          env, ty = localize_type(ty, env, ep)
          env = env.push(ty)
        else
          add_gvar_read!(var, ep) do |ty, ep|
            ty = Type.nil if ty == Type.bot # HACK
            nenv, ty = localize_type(ty, env, ep)
            merge_env(ep.next, nenv.push(ty))
          end
          # need to return default nil of global variables
          return
        end

      when :getlocal, :getblockparam, :getblockparamproxy
        var_idx, scope_idx, _escaped = operands
        if scope_idx == 0
          ty = env.get_local(-var_idx+2)
        else
          tmp_ep = ep
          scope_idx.times do
            tmp_ep = tmp_ep.outer
          end
          ty = @return_envs[tmp_ep].get_local(-var_idx+2)
        end
        env = env.push(ty)
      when :getlocal_branch
        getlocal_operands, branch_operands = operands
        var_idx, _scope_idx, _escaped = getlocal_operands
        ret_ty = env.get_local(-var_idx+2)

        branchtype, target, = branch_operands
        # branchtype: :if or :unless or :nil
        ep_then = ep.next
        ep_else = ep.jump(target)

        var_idx, _scope_idx, _escaped = getlocal_operands

        ret_ty.each_child do |ret_ty|
          flow_env = env.local_update(-var_idx+2, ret_ty)
          case ret_ty
          when Type.any
            merge_env(ep_then, env)
            merge_env(ep_else, env)
          when Type::Instance.new(Type::Builtin[:false]), Type.nil
            merge_env(branchtype == :if ? ep_then : ep_else, flow_env)
          else
            merge_env(branchtype == :if ? ep_else : ep_then, flow_env)
          end
        end
        return
      when :getlocal_checkmatch_branch
        getlocal_operands, branch_operands = operands
        var_idx, _scope_idx, _escaped = getlocal_operands
        ret_ty = env.get_local(-var_idx+2)

        env, (pattern_ty,) = env.pop(1)

        branchtype, target, = branch_operands
        # branchtype: :if or :unless or :nil
        ep_then = ep.next
        ep_else = ep.jump(target)

        var_idx, _scope_idx, _escaped = getlocal_operands

        ret_ty.each_child do |ret_ty|
          flow_env = env.local_update(-var_idx+2, ret_ty)
          if ret_ty.is_a?(Type::Instance)
            if ret_ty.klass == pattern_ty # XXX: inheritance
              merge_env(branchtype == :if ? ep_else : ep_then, flow_env)
            else
              merge_env(branchtype == :if ? ep_then : ep_else, flow_env)
            end
          else
            merge_env(ep_then, env)
            merge_env(ep_else, env)
          end
        end
        return
      when :setlocal, :setblockparam
        var_idx, scope_idx, _escaped = operands
        env, (ty,) = env.pop(1)
        if scope_idx == 0
          env = env.local_update(-var_idx+2, ty)
        else
          tmp_ep = ep
          scope_idx.times do
            tmp_ep = tmp_ep.outer
          end
          merge_return_env(tmp_ep) do |env|
            env.merge(env.local_update(-var_idx+2, ty))
          end
        end
      when :getconstant
        name, = operands
        env, (cbase, _allow_nil,) = env.pop(2)
        if cbase.eql?(Type.nil)
          ty = search_constant(ep.ctx.cref, name)
          env, ty = localize_type(ty, env, ep)
          env = env.push(ty)
        elsif cbase.eql?(Type.any)
          env = env.push(Type.any) # XXX: warning needed?
        else
          ty = get_constant(cbase, name)
          env, ty = localize_type(ty, env, ep)
          env = env.push(ty)
        end
      when :setconstant
        name, = operands
        env, (ty, cbase) = env.pop(2)
        old_ty = get_constant(cbase, name)
        if old_ty != Type.any # XXX???
          warn(ep, "already initialized constant #{ Type::Instance.new(cbase).screen_name(self) }::#{ name }")
        end
        ty.each_child do |ty|
          if ty.is_a?(Type::Class) && ty.superclass == Type::Builtin[:struct]
            @class_defs[ty.idx].name = name.to_s
          end
        end
        add_constant(cbase, name, globalize_type(ty, env, ep))

      when :getspecial
        key, type = operands
        if type == 0
          raise NotImplementedError
          case key
          when 0 # VM_SVAR_LASTLINE
            env = env.push(Type.any) # or String | NilClass only?
          when 1 # VM_SVAR_BACKREF ($~)
            merge_env(ep.next, env.push(Type::Instance.new(Type::Builtin[:matchdata])))
            merge_env(ep.next, env.push(Type.nil))
            return
          else # flip-flop
            env = env.push(Type.bool)
          end
        else
          # NTH_REF ($1, $2, ...) / BACK_REF ($&, $+, ...)
          merge_env(ep.next, env.push(Type::Instance.new(Type::Builtin[:str])))
          merge_env(ep.next, env.push(Type.nil))
          return
        end
      when :setspecial
        # flip-flop
        raise NotImplementedError, "setspecial"

      when :dup
        env, (ty,) = env.pop(1)
        env = env.push(ty).push(ty)
      when :duphash
        raw_hash, = operands
        ty = Type.guess_literal_type(raw_hash)
        env, ty = localize_type(globalize_type(ty, env, ep), env, ep)
        env = env.push(ty)
      when :dupn
        n, = operands
        _, tys = env.pop(n)
        tys.each {|ty| env = env.push(ty) }
      when :pop
        env, = env.pop(1)
      when :swap
        env, (a, b) = env.pop(2)
        env = env.push(a).push(b)
      when :reverse
        raise NotImplementedError, "reverse"
      when :defined
        env, = env.pop(1)
        sym_ty = Type::Symbol.new(nil, Type::Instance.new(Type::Builtin[:sym]))
        env = env.push(Type.optional(sym_ty))
      when :checkmatch
        flag, = operands
        array = flag & 4 != 0
        case flag & 3
        when 1
          raise NotImplementedError
        when 2 # VM_CHECKMATCH_TYPE_CASE
          #raise NotImplementedError if array
          env, = env.pop(2)
          env = env.push(Type.bool)
        when 3 # VM_CHECKMATCH_TYPE_RESCUE
          env, = env.pop(2)
          env = env.push(Type.bool)
        else
          raise "unknown checkmatch flag"
        end
      when :checkkeyword
        env = env.push(Type.bool)
      when :adjuststack
        n, = operands
        env, _ = env.pop(n)
      when :nop
      when :setn
        idx, = operands
        env, (ty,) = env.pop(1)
        env = env.setn(idx, ty).push(ty)
      when :topn
        idx, = operands
        env = env.topn(idx)

      when :splatarray
        env, (ty,) = env.pop(1)
        # XXX: vm_splat_array
        env = env.push(ty)
      when :expandarray
        num, flag = operands
        env, (ary,) = env.pop(1)
        splat = flag & 1 == 1
        from_head = flag & 2 == 0
        ary.each_child do |ary|
          case ary
          when Type::LocalArray
            elems = get_container_elem_types(env, ep, ary.id)
            elems ||= Type::Array::Elements.new([], Type.any) # XXX
            do_expand_array(ep, env, elems, num, splat, from_head)
          when Type::Any
            nnum = num
            nnum += 1 if splat
            nenv = env
            nnum.times do
              nenv = nenv.push(Type.any)
            end
            add_edge(ep, ep)
            merge_env(ep.next, nenv)
          else
            # TODO: call to_ary (or to_a?)
            elems = Type::Array::Elements.new([ary], Type.bot)
            do_expand_array(ep, env, elems, num, splat, from_head)
          end
        end
        return
      when :concatarray
        env, (ary1, ary2) = env.pop(2)
        if ary1.is_a?(Type::LocalArray)
          elems1 = get_container_elem_types(env, ep, ary1.id)
          if ary2.is_a?(Type::LocalArray)
            elems2 = get_container_elem_types(env, ep, ary2.id)
            elems = Type::Array::Elements.new([], elems1.squash.union(elems2.squash))
            env = update_container_elem_types(env, ep, ary1.id) { elems }
            env = env.push(ary1)
          else
            elems = Type::Array::Elements.new([], Type.any)
            env = update_container_elem_types(env, ep, ary1.id) { elems }
            env = env.push(ary1)
          end
        else
          ty = Type::Array.new(Type::Array::Elements.new([], Type.any), Type::Instance.new(Type::Builtin[:ary]))
          env, ty = localize_type(ty, env, ep)
          env = env.push(ty)
        end

      when :checktype
        type, = operands
        raise NotImplementedError if type != 5 # T_STRING
        # XXX: is_a?
        env, (val,) = env.pop(1)
        res = globalize_type(val, env, ep) == Type::Instance.new(Type::Builtin[:str])
        if res
          ty = Type::Instance.new(Type::Builtin[:true])
        else
          ty = Type::Instance.new(Type::Builtin[:false])
        end
        env = env.push(ty)
      else
        raise "Unknown insn: #{ insn }"
      end

      add_edge(ep, ep)
      merge_env(ep.next, env)

      if ep.ctx.iseq.catch_table[ep.pc]
        ep.ctx.iseq.catch_table[ep.pc].each do |type, iseq, cont, stack_depth|
          next if type != :rescue && type != :ensure
          next if env.stack.size < stack_depth
          cont_ep = ep.jump(cont)
          cont_env, = env.pop(env.stack.size - stack_depth)
          nctx = Context.new(iseq, ep.ctx.cref, ep.ctx.mid)
          nep = ExecutionPoint.new(nctx, 0, cont_ep)
          locals = [Type.nil] * iseq.locals.size
          nenv = Env.new(env.static_env, locals, [], Utils::HashWrapper.new({}))
          merge_env(nep, nenv)
          add_callsite!(nep.ctx, nil, cont_ep, cont_env) do |ret_ty, ep, env|
            nenv, ret_ty = localize_type(ret_ty, env, ep)
            nenv = nenv.push(ret_ty)
            merge_env(ep.jump(cont), nenv)
          end
        end
      end
    end

    private def do_expand_array(ep, env, elems, num, splat, from_head)
      if from_head
        lead_tys, rest_ary_ty = elems.take_first(num)
        if splat
          env, local_ary_ty = localize_type(rest_ary_ty, env, ep)
          env = env.push(local_ary_ty)
        end
        lead_tys.reverse_each do |ty|
          env = env.push(ty)
        end
      else
        rest_ary_ty, following_tys = elems.take_last(num)
        following_tys.each do |ty|
          env = env.push(ty)
        end
        if splat
          env, local_ary_ty = localize_type(rest_ary_ty, env, ep)
          env = env.push(local_ary_ty)
        end
      end
      merge_env(ep.next, env)
    end

    private def setup_actual_arguments(operands, ep, env)
      opt, blk_iseq = operands
      flags = opt[:flag]
      mid = opt[:mid]
      kw_arg = opt[:kw_arg]
      argc = opt[:orig_argc]
      argc += 1 # receiver
      argc += kw_arg.size if kw_arg

      flag_args_splat    = flags[ 0] != 0
      flag_args_blockarg = flags[ 1] != 0
      _flag_args_fcall   = flags[ 2] != 0
      _flag_args_vcall   = flags[ 3] != 0
      _flag_args_simple  = flags[ 4] != 0 # unused in TP
      _flag_blockiseq    = flags[ 5] != 0 # unused in VM :-)
      flag_args_kwarg    = flags[ 6] != 0
      flag_args_kw_splat = flags[ 7] != 0
      _flag_tailcall     = flags[ 8] != 0
      _flag_super        = flags[ 9] != 0
      _flag_zsuper       = flags[10] != 0

      if flag_args_blockarg
        env, (recv, *aargs, blk_ty) = env.pop(argc + 1)
        raise "both block arg and actual block given" if blk_iseq
      else
        env, (recv, *aargs) = env.pop(argc)
        if blk_iseq
          # check
          blk_ty = Type::ISeqProc.new(blk_iseq, ep, Type::Instance.new(Type::Builtin[:proc]))
        else
          blk_ty = Type.nil
        end
      end

      blk_ty.each_child do |blk_ty|
        case blk_ty
        when Type.nil
        when Type.any
        when Type::ISeqProc
        else
          error(ep, "wrong argument type #{ blk_ty.screen_name(self) } (expected Proc)")
          blk_ty = Type.any
        end
      end

      if flag_args_splat
        # assert !flag_args_kwarg
        rest_ty = aargs.last
        aargs = aargs[0..-2]
        if flag_args_kw_splat
          ty = globalize_type(rest_ty, env, ep)
          if ty.is_a?(Type::Array)
            _, (ty,) = ty.elems.take_last(1)
            case ty
            when Type::Hash
              kw_ty = ty
            when Type::Union
              hash_elems = nil
              ty.elems.each do |(container_kind, base_type), elems|
                if container_kind == Type::Hash
                  hash_elems = hash_elems ? hash_elems.union(elems) : elems
                end
              end
              hash_elems ||= Type::Hash::Elements.new({Type.any => Type.any})
              kw_ty = Type::Hash.new(hash_elems, Type::Instance.new(Type::Builtin[:hash]))
            else
              warn(ep, "non hash is passed to **kwarg?") unless ty == Type.any
              kw_ty = nil
            end
          else
            raise NotImplementedError
          end
          # XXX: should we remove kw_ty from rest_ty?
        end
        aargs = ActualArguments.new(aargs, rest_ty, kw_ty, blk_ty)
      elsif flag_args_kw_splat
        last = aargs.last
        ty = globalize_type(last, env, ep)
        case ty
        when Type::Hash
          aargs = aargs[0..-2]
          kw_ty = ty
        when Type::Union
          hash_elems = nil
          ty.elems.each do |(container_kind, base_type), elems|
            if container_kind == Type::Hash
              hash_elems = hash_elems ? hash_elems.union(elems) : elems
            end
          end
          hash_elems ||= Type::Hash::Elements.new({Type.any => Type.any})
          kw_ty = Type::Hash.new(hash_elems, Type::Instance.new(Type::Builtin[:hash]))
        when Type::Any
          aargs = aargs[0..-2]
          kw_ty = ty
        else
          warn(ep, "non hash is passed to **kwarg?")
          kw_ty = nil
        end
        aargs = ActualArguments.new(aargs, nil, kw_ty, blk_ty)
      elsif flag_args_kwarg
        kw_vals = aargs.pop(kw_arg.size)

        kw_ty = Type.gen_hash do |h|
          kw_arg.zip(kw_vals) do |key, v_ty|
            k_ty = Type::Symbol.new(key, Type::Instance.new(Type::Builtin[:sym]))
            h[k_ty] = v_ty
          end
        end

        # kw_ty is Type::Hash, but we don't have to localize it, maybe?

        aargs = ActualArguments.new(aargs, nil, kw_ty, blk_ty)
      else
        aargs = ActualArguments.new(aargs, nil, nil, blk_ty)
      end

      if blk_iseq
        # pending dummy execution
        nctx = Context.new(blk_iseq, ep.ctx.cref, ep.ctx.mid)
        nep = ExecutionPoint.new(nctx, 0, ep)
        nlocals = [Type.any] * blk_iseq.locals.size
        nsenv = StaticEnv.new(env.static_env.recv_ty, Type.any, env.static_env.mod_func)
        nenv = Env.new(nsenv, nlocals, [], nil)
        pend_block_dummy_execution(blk_iseq, nep, nenv)
        merge_return_env(ep) {|tenv| tenv ? tenv.merge(env) : env }
      end

      return env, recv, mid, aargs
    end

    def do_send(recv, mid, aargs, ep, env, &ctn)
      meths = recv.get_method(mid, self)
      if meths
        meths.each do |meth|
          meth.do_send(recv, mid, aargs, ep, env, self, &ctn)
        end
      else
        if recv != Type.any # XXX: should be configurable
          error(ep, "undefined method: #{ globalize_type(recv, env, ep).screen_name(self) }##{ mid }")
        end
        ctn[Type.any, ep, env]
      end
    end

    def do_invoke_block(given_block, blk, aargs, ep, env, replace_recv_ty: nil, &ctn)
      blk.each_child do |blk|
        unless blk.is_a?(Type::ISeqProc)
          warn(ep, "non-iseq-proc is passed as a block")
          next
        end
        blk_iseq = blk.iseq
        blk_ep = blk.ep
        blk_env = @return_envs[blk_ep]
        blk_env = blk_env.replace_recv_ty(replace_recv_ty) if replace_recv_ty
        arg_blk = aargs.blk_ty
        aargs_ = aargs.lead_tys.map {|aarg| globalize_type(aarg, env, ep) }
        argc = blk_iseq.fargs_format[:lead_num] || 0
        # actual argc == 1, not array, formal argc == 1: yield 42         => do |x|   : x=42
        # actual argc == 1,     array, formal argc == 1: yield [42,43,44] => do |x|   : x=[42,43,44]
        # actual argc >= 2,            formal argc == 1: yield 42,43,44   => do |x|   : x=42
        # actual argc == 1, not array, formal argc >= 2: yield 42         => do |x,y| : x,y=42,nil
        # actual argc == 1,     array, formal argc >= 2: yield [42,43,44] => do |x,y| : x,y=42,43
        # actual argc >= 2,            formal argc >= 2: yield 42,43,44   => do |x,y| : x,y=42,43
        if aargs_.size >= 2 || argc == 0
          aargs_.pop while argc < aargs_.size
          aargs_ << Type.nil while argc > aargs_.size
        else
          aarg_ty, = aargs_
          if argc == 1
            aargs_ = [aarg_ty || Type.nil]
          else # actual argc == 1 && formal argc >= 2
            ary_elems = nil
            any_ty = nil
            case aarg_ty
            when Type::Union
              ary_elems = nil
              other_elems = nil
              aarg_ty.elems&.each do |(container_kind, base_type), elems|
                if container_kind == Type::Array
                  ary_elems = ary_elems ? ary_elems.union(elems) : elems
                else
                  other_elems = other_elems ? other_elems.union(elems) : elems
                end
              end
              aarg_ty = Type::Union.new(aarg_ty.types, other_elems)
              any_ty = Type.any if aarg_ty.types.include?(Type.any)
            when Type::Array
              ary_elems = aarg_ty.elems
              aarg_ty = nil
            when Type::Any
              any_ty = Type.any
            end
            aargs_ = [Type.bot] * argc
            aargs_[0] = aargs_[0].union(aarg_ty) if aarg_ty
            argc.times do |i|
              ty = aargs_[i]
              ty = ty.union(ary_elems[i]) if ary_elems
              ty = ty.union(Type.any) if any_ty
              ty = ty.union(Type.nil) if i >= 1 && aarg_ty
              aargs_[i] = ty
            end
          end
        end
        locals = [Type.nil] * blk_iseq.locals.size
        locals[blk_iseq.fargs_format[:block_start]] = arg_blk if blk_iseq.fargs_format[:block_start]
        env_blk = blk_env.static_env.blk_ty
        nfargs = FormalArguments.new(aargs_, [], nil, [], nil, nil, env_blk) # XXX: aargs_ -> fargs
        nctx = Context.new(blk_iseq, blk_ep.ctx.cref, nil)
        nep = ExecutionPoint.new(nctx, 0, blk_ep)
        nenv = Env.new(blk_env.static_env, locals, [], nil)
        alloc_site = AllocationSite.new(nep)
        aargs_.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(i)
          nenv, ty = localize_type(ty, nenv, nep, alloc_site2) # Use Scratch#localize_type?
          nenv = nenv.local_update(i, ty)
        end

        merge_env(nep, nenv)

        # caution: given_block flag is not complete
        #
        # def foo
        #   bar do |&blk|
        #     yield
        #     blk.call
        #   end
        # end
        #
        # yield and blk.call call different blocks.
        # So, a context can have two blocks.
        # given_block is calculated by comparing "context's block (yield target)" and "blk", but it is not a correct result

        add_yield!(ep.ctx, globalize_type(aargs, env, ep), nep.ctx) if given_block
        add_block_to_ctx!(blk, nep.ctx)
        add_callsite!(nep.ctx, nfargs, ep, env, &ctn)
      end
    end

    def proc_screen_name(blk)
      blk_ctxs = []
      blk.each_child_global do |blk|
        if @block_to_ctx[blk]
          @block_to_ctx[blk].each do |ctx|
            blk_ctxs << [ctx, @sig_fargs[ctx]]
          end
        else
          # uncalled proc? dummy execution doesn't work?
          #p blk
        end
      end
      show_block_signature(blk_ctxs)
    end

    def show_block_signature(blk_ctxs)
      blk_tys = {}
      all_farg_tys = all_ret_tys = nil
      blk_ctxs.each do |blk_ctx, farg_tys|
        if all_farg_tys
          all_farg_tys = all_farg_tys.merge(farg_tys)
        else
          all_farg_tys = farg_tys
        end

        if all_ret_tys
          all_ret_tys = all_ret_tys.union(@sig_ret[blk_ctx])
        else
          all_ret_tys = @sig_ret[blk_ctx]
        end
      end
      return "" if !all_farg_tys
      # XXX: should support @yields[blk_ctx] (block's block)
      show_signature(all_farg_tys, nil, all_ret_tys)
    end

    def show_signature(farg_tys, yield_data, ret_ty)
      farg_tys = farg_tys.screen_name(self)
      ret_ty = ret_ty.screen_name(self)
      s = farg_tys.empty? ? "" : "(#{ farg_tys.join(", ") }) "
      if yield_data
        aargs, blk_ctxs = yield_data
        all_blk_ret_ty = Type.bot
        blk_ctxs.each do |blk_ctx|
          all_blk_ret_ty = all_blk_ret_ty.union(@sig_ret[blk_ctx])
        end
        all_blk_ret_ty = all_blk_ret_ty.screen_name(self)
        all_blk_ret_ty = all_blk_ret_ty.include?("|") ? "(#{ all_blk_ret_ty })" : all_blk_ret_ty
        s << "{ #{ aargs.screen_name(self) } -> #{ all_blk_ret_ty } } " if aargs
      end
      s << "-> "
      s << (ret_ty.include?("|") ? "(#{ ret_ty })" : ret_ty)
    end
  end
end
