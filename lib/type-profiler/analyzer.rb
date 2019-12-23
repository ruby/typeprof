module TypeProfiler
  class CRef
    include Utils::StructuralEquality

    def initialize(outer, klass)
      @outer = outer
      @klass = klass
      # flags
      # scope_visi (= method_visi * module_func_flag)
      # refinements
    end

    def extend(klass)
      CRef.new(self, klass)
    end

    attr_reader :outer, :klass

    def pretty_print(q)
      q.text "CRef["
      q.pp @klass
      q.text "]"
    end
  end

  class Context
    include Utils::StructuralEquality

    def initialize(iseq, cref, sig)
      @iseq = iseq
      @cref = cref
      @sig = sig
    end

    attr_reader :iseq, :cref, :sig
  end

  class ExecutionPoint
    include Utils::StructuralEquality

    def initialize(ctx, pc, outer)
      @ctx = ctx
      @pc = pc
      @outer = outer
    end

    def key
      [@ctx.iseq, @pc, @sig]
    end

    attr_reader :ctx, :pc, :outer

    def jump(pc)
      ExecutionPoint.new(@ctx, pc, @outer)
    end

    def next
      ExecutionPoint.new(@ctx, @pc + 1, @outer)
    end

    def source_location
      @ctx.iseq.source_location(@pc)
    end
  end

  class Env
    include Utils::StructuralEquality

    def initialize(locals, stack, type_params)
      @locals = locals
      @stack = stack
      @type_params = type_params
    end

    attr_reader :locals, :stack, :type_params

    def merge(other)
      raise if @locals.size != other.locals.size
      raise if @stack.size != other.stack.size
      locals = @locals.zip(other.locals).map {|ty1, ty2| ty1.union(ty2) }
      stack = @stack.zip(other.stack).map {|ty1, ty2| ty1.union(ty2) }
      type_params = @type_params.dup
      other.type_params.each do |id, elems|
        if type_params[id]
          type_params[id] = type_params[id].union(elems)
        else
          type_params[id] = elems
        end
      end
      Env.new(locals, stack, type_params)
    end

    def push(*tys)
      tys.each do |ty|
        raise "Array cannot be pushed to the stack" if ty.is_a?(Type::Array)
        raise "nil cannot be pushed to the stack" if ty.nil?
        if ty.is_a?(Type::Union) && ty.each.any? {|ty| ty.is_a?(Type::Array) }
          raise "Array (in Union type) cannot be pushed to the stack"
        end
      end
      Env.new(@locals, @stack + tys, @type_params)
    end

    def pop(n)
      stack = @stack.dup
      tys = stack.pop(n)
      nenv = Env.new(@locals, stack, @type_params)
      return nenv, tys
    end

    def setn(i, ty)
      stack = Utils.array_update(@stack, -i, ty)
      Env.new(@locals, stack, @type_params)
    end

    def topn(i)
      push(@stack[-i - 1])
    end

    def get_local(idx)
      @locals[idx]
    end

    def local_update(idx, ty)
      Env.new(Utils.array_update(@locals, idx, ty), @stack, @type_params)
    end

    def deploy_array_type(alloc_site, elems, base_ty)
      local_ty = Type::LocalArray.new(alloc_site, base_ty)
      type_params = @type_params.merge({ alloc_site => elems })
      nenv = Env.new(@locals, @stack, type_params)
      return nenv, local_ty
    end

    def get_array_elem_types(id)
      # need to check this in the caller side
      @type_params[id]# || @outer.get_array_elem_types(id)
    end

    def update_array_elem_types(id, elems)
      type_params = @type_params.merge({ id => elems })
      Env.new(@locals, @stack, type_params)
    end

    def poke_array_elem_types(id, idx, ty)
      if @type_params[id]
        elems = @type_params[id].update(idx, ty)
        type_params = @type_params.merge({ id => elems })
        Env.new(@locals, @stack, type_params)
      else
        nil
      end
    end

    def inspect
      "Env[locals:#{ @locals.inspect }, stack:#{ @stack.inspect }, type_params:#{ @type_params.inspect }]"
    end
  end

  class Scratch
    def initialize
      @worklist = Utils::WorkList.new

      @ep2env = {}

      @class_defs = {}

      @callsites, @return_envs, @signatures, @yields = {}, {}, {}, {}
      @ivar_read, @ivar_write = {}, {}
      @gvar_read, @gvar_write = {}, {}

      @errors = []
      @backward_edges = {}
    end

    attr_reader :return_envs

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

    class ClassDef
      def initialize(name, superclass)
        @superclass = superclass
        @name = name
        @consts = {}
        @methods = {}
        @singleton_methods = {}
      end

      def get_constant(name)
        @consts[name] || Type::Any.new # XXX: warn?
      end

      def add_constant(name, ty)
        if @consts[name]
          # XXX: warn!
        end
        @consts[name] = ty
      end

      def get_method(mid)
        # TODO: support multiple methods?
        @methods[mid]
      end

      def add_method(mid, mdef)
        @methods[mid] ||= Utils::MutableSet.new
        @methods[mid] << mdef
        # Need to restart...?
      end

      def get_singleton_method(mid)
        @singleton_methods[mid]
      end

      def add_singleton_method(mid, mdef)
        @singleton_methods[mid] ||= Utils::MutableSet.new
        @singleton_methods[mid] << mdef
      end

      attr_reader :name, :methods, :superclass
    end

    def new_class(cbase, name, superclass)
      if cbase && cbase.idx != 0
        class_name = "#{ @class_defs[cbase.idx].name }::#{ name }"
      else
        class_name = name.to_s
      end
      idx = @class_defs.size
      @class_defs[idx] = ClassDef.new(class_name, superclass && superclass.idx)
      klass = Type::Class.new(idx, name)
      cbase ||= klass # for bootstrap
      add_constant(cbase, name, klass)
      return klass
    end

    def get_class_name(klass)
      if klass == Type::Any.new
        "???"
      else
        @class_defs[klass.idx].name
      end
    end

    def get_method(klass, mid)
      idx = klass.idx
      while idx
        mthd = @class_defs[idx].get_method(mid)
        # Need to be conservative to include all super candidates...?
        return mthd if mthd
        idx = @class_defs[idx].superclass
      end
      nil
    end

    def get_singleton_method(klass, mid)
      idx = klass.idx
      while idx
        mthd = @class_defs[idx].get_singleton_method(mid)
        # Need to be conservative to include all super candidates...?
        return mthd if mthd
        idx = @class_defs[idx].superclass
      end
      nil
    end

    def get_super_method(klass, mid)
      idx = klass.idx
      idx = @class_defs[idx].superclass
      while idx
        mthd = @class_defs[idx].get_method(mid)
        return mthd if mthd
        idx = @class_defs[idx].superclass
      end
      nil
    end

    def get_superclass(klass)
      idx = klass.idx
      idx = @class_defs[idx].superclass
      Type::Class.new(idx, nil)
    end

    def get_constant(klass, name)
      if klass == Type::Any.new
        Type::Any.new
      else
        @class_defs[klass.idx].get_constant(name)
      end
    end

    def search_constant(cref, name)
      while cref != :bottom
        val = get_constant(cref.klass, name)
        return val if val != Type::Any.new
        cref = cref.outer
      end

      Type::Any.new
    end

    def add_constant(klass, name, value)
      if klass == Type::Any.new
        self
      else
        @class_defs[klass.idx].add_constant(name, value)
      end
    end

    def add_method(klass, mid, mdef)
      if klass == Type::Any.new
        self # XXX warn
      else
        @class_defs[klass.idx].add_method(mid, mdef)
      end
    end

    def add_singleton_method(klass, mid, mdef)
      if klass == Type::Any.new
        self # XXX warn
      else
        @class_defs[klass.idx].add_singleton_method(mid, mdef)
      end
    end

    def add_iseq_method(klass, mid, iseq, cref)
      add_method(klass, mid, ISeqMethodDef.new(iseq, cref, false))
    end

    def add_singleton_iseq_method(klass, mid, iseq, cref)
      add_singleton_method(klass, mid, ISeqMethodDef.new(iseq, cref, true))
    end

    def add_typed_method(recv_ty, mid, fargs, ret_ty)
      sig = Signature.new(recv_ty, false, mid, fargs)
      add_method(recv_ty.klass, mid, TypedMethodDef.new([[sig, ret_ty]]))
    end

    def add_singleton_typed_method(recv_ty, mid, fargs, ret_ty)
      sig = Signature.new(recv_ty, true, mid, fargs)
      add_singleton_method(recv_ty.klass, mid, TypedMethodDef.new([[sig, ret_ty]]))
    end

    def add_custom_method(klass, mid, impl)
      add_method(klass, mid, CustomMethodDef.new(impl))
    end

    def add_singleton_custom_method(klass, mid, impl)
      add_singleton_method(klass, mid, CustomMethodDef.new(impl))
    end

    def alias_method(klass, new, old)
      if klass == Type::Any.new
        self
      else
        klass_def = @class_defs[klass.idx]
        klass_def.get_method(old).each do |mdef|
          klass_def.add_method(new, mdef)
        end
      end
    end

    def add_edge(ep, next_ep)
      (@backward_edges[next_ep] ||= {})[ep] = true
    end

    def add_callsite!(callee_ctx, caller_ep, caller_env, &ctn)
      @callsites[callee_ctx] ||= {}
      @callsites[callee_ctx][caller_ep] = ctn
      merge_return_env(caller_ep) {|env| env ? env.merge(caller_env) : caller_env }

      ret_ty = @signatures[callee_ctx] ||= Type::Union.new(Utils::Set[])
      if ret_ty != Type::Union.new(Utils::Set[])
        @callsites[callee_ctx].each do |caller_ep, ctn|
          ctn[ret_ty, caller_ep, @return_envs[caller_ep]] # TODO: use Union type
        end
      end
    end

    def merge_return_env(caller_ep)
      @return_envs[caller_ep] = yield @return_envs[caller_ep]
    end

    def add_return_type!(callee_ctx, ret_ty)
      @signatures[callee_ctx] ||= Type::Union.new(Utils::Set.new())
      @signatures[callee_ctx] = @signatures[callee_ctx].union(ret_ty)

      #@callsites[callee_ctx] ||= {} # needed?
      @callsites[callee_ctx].each do |caller_ep, ctn|
        ctn[ret_ty, caller_ep, @return_envs[caller_ep]]
      end
    end

    def add_yield!(caller_ctx, blk_ctx)
      @yields[caller_ctx] ||= Utils::MutableSet.new
      @yields[caller_ctx] << blk_ctx
    end

    def add_ivar_read!(recv, var, ep, &ctn)
      site = [recv, var]
      @ivar_read[site] ||= {}
      @ivar_read[site][ep] = ctn
      @ivar_write[site] ||= Utils::MutableSet.new
      @ivar_write[site].each do |ty|
        ctn[ty, ep] # TODO: use Union type
      end
    end

    def add_ivar_write!(recv, var, ty, &ctn)
      site = [recv, var]
      @ivar_write[site] ||= Utils::MutableSet.new
      @ivar_write[site] << ty
      @ivar_read[site] ||= {}
      @ivar_read[site].each do |ep, ctn|
        ctn[ty, ep] # TODO: use Union type
      end
    end

    def add_gvar_read!(var, ep, &ctn)
      @gvar_read[var] ||= {}
      @gvar_read[var][ep] = ctn
      @gvar_write[var] ||= Utils::MutableSet.new
      @gvar_write[var].each do |ty|
        ctn[ty, ep] # TODO: use Union type
      end
    end

    def add_gvar_write!(var, ty, &ctn)
      @gvar_write[var] ||= Utils::MutableSet.new
      @gvar_write[var] << ty
      @gvar_read[var] ||= {}
      @gvar_read[var].each do |ep, ctn|
        ctn[ty, ep]
      end
    end

    def error(ep, msg)
      p [ep.source_location, "[error] " + msg] if ENV["TP_DEBUG"]
      @errors << [ep, "[error] " + msg]
    end

    def warn(ep, msg)
      p [ep.source_location, "[warning] " + msg] if ENV["TP_DEBUG"]
      @errors << [ep, "[warning] " + msg]
    end

    def reveal_type(ep, msg)
      p [ep.source_location, "[p] " + msg] if ENV["TP_DEBUG"]
      @errors << [ep, "[p] " + msg]
    end

    def type_profile
      counter = 0
      stat_eps = Utils::MutableSet.new
      until @worklist.empty?
        counter += 1
        if counter % 1000 == 0
          puts "iter %d, remain: %d" % [counter, @worklist.size]
        end
        @ep = @worklist.deletemin
        @env = @ep2env[@ep]
        stat_eps << @ep
        step(@ep) # TODO: deletemin
      end
      RubySignatureExporter.new(
        self, @errors, @gvar_write, @ivar_write,
        @signatures, @yields, @backward_edges,
      ).show(stat_eps)
    end

    def step(ep)
      orig_ep = ep
      env = @ep2env[ep]
      scratch = self
      raise "nil env" unless env

      insn, *operands = ep.ctx.iseq.insns[ep.pc]

      if ENV["TP_DEBUG"]
        p [ep.pc, ep.ctx.iseq.name, ep.source_location, insn, operands]
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
        env = env.push(Type::Instance.new(Type::Builtin[:nil]))
      when :putobject, :duparray
        obj, = operands
        env, ty = Type.guess_literal_type(obj).deploy_local(env, ep)
        env = env.push(ty)
      when :putstring
        str, = operands
        ty = Type::Literal.new(str, Type::Instance.new(Type::Builtin[:str]))
        env = env.push(ty)
      when :putself
        env = env.push(ep.ctx.sig.recv_ty)
      when :newarray, :newarraykwsplat
        len, = operands
        env, elems = env.pop(len)
        ty = Type::Array.tuple(elems.map {|elem| Utils::Set[elem] }, Type::Instance.new(Type::Builtin[:ary]))
        env, ty = ty.deploy_local(env, ep)
        env = env.push(ty)
      when :newhash
        # XXX
        num, = operands
        env, = env.pop(num)
        env = env.push(Type::Any.new)
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
        raise NotImplementedError, "freezestring"
      when :toregexp
        raise NotImplementedError, "toregexp"
      when :intern
        env, (ty,) = env.pop(1)
        # XXX check if ty is String
        env = env.push(Type::Instance.new(Type::Builtin[:sym]))

      when :definemethod
        mid, iseq = operands
        cref = ep.ctx.cref
        scratch.add_iseq_method(cref.klass, mid, iseq, cref)
      when :definesmethod
        mid, iseq = operands
        env, (recv,) = env.pop(1)
        cref = ep.ctx.cref
        scratch.add_singleton_iseq_method(recv, mid, iseq, cref)
      when :defineclass
        id, iseq, flags = operands
        env, (cbase, superclass) = env.pop(2)
        case flags & 7
        when 0, 2 # CLASS / MODULE
          scratch.warn(ep, "module is not supported yet") if flags & 7 == 2
          existing_klass = scratch.get_constant(cbase, id) # TODO: multiple return values
          if existing_klass.is_a?(Type::Class)
            klass = existing_klass
          else
            if existing_klass != Type::Any.new
              scratch.error(ep, "the class \"#{ id }\" is #{ existing_klass.screen_name(scratch) }")
              id = :"#{ id }(dummy)"
            end
            existing_klass = scratch.get_constant(cbase, id) # TODO: multiple return values
            if existing_klass != Type::Any.new
              klass = existing_klass
            else
              if superclass == Type::Any.new
                scratch.warn(ep, "superclass is any; Object is used instead")
                superclass = Type::Builtin[:obj]
              elsif superclass.eql?(Type::Instance.new(Type::Builtin[:nil]))
                superclass = Type::Builtin[:obj]
              end
              klass = scratch.new_class(cbase, id, superclass)
            end
          end
        when 1 # SINGLETON_CLASS
          raise NotImplementedError
        else
          raise NotImplementedError, "unknown defineclass flag: #{ flags }"
        end
        ncref = ep.ctx.cref.extend(klass)
        recv = klass
        blk = ep.ctx.sig.fargs.blk_ty
        nctx = Context.new(iseq, ncref, Signature.new(recv, nil, nil, FormalArguments.new([], [], nil, [], nil, blk)))
        nep = ExecutionPoint.new(nctx, 0, nil)
        nenv = Env.new([], [], {})
        merge_env(nep, nenv)
        scratch.add_callsite!(nep.ctx, ep, env) do |ret_ty, ep, env|
          nenv, ret_ty = ret_ty.deploy_local(env, ep)
          nenv = nenv.push(ret_ty)
          merge_env(ep.next, nenv)
        end
        return
      when :send
        env, recvs, mid, aargs = Aux.setup_actual_arguments(scratch, operands, ep, env)
        recvs.each do |recv|
          meths = recv.get_method(mid, scratch)
          if meths
            meths.each do |meth|
              meth.do_send(self, flags, recv, mid, aargs, ep, env, scratch)
            end
          else
            if recv != Type::Any.new # XXX: should be configurable
              scratch.error(ep, "undefined method: #{ recv.strip_local_info(env).screen_name(scratch) }##{ mid }")
            end
            nenv = env.push(Type::Any.new)
            merge_env(ep.next, nenv)
          end
        end
        return
      when :send_is_a_and_branch
        send_operands, (branch_type, target,) = *operands
        env, recvs, mid, aargs = Aux.setup_actual_arguments(scratch, send_operands, ep, env)
        recvs.each do |recv|
          meths = recv.get_method(mid, scratch)
          if meths
            meths.each do |meth|
              meth.do_send(self, flags, recv, mid, aargs, ep, env, scratch) do |ret_ty, ep, env|
                if branch_type != :nil && ret_ty.is_a?(Type::Literal)
                  if !!ret_ty.lit == (branch_type == :if)
                    nep = ep.jump(target)
                    merge_env(nep, env)
                  else
                    nep = ep.next
                    merge_env(nep, env)
                  end
                else
                  ep_then = ep.next
                  ep_else = ep.jump(target)

                  merge_env(ep_then, env)
                  merge_env(ep_else, env)
                end
              end
            end
          else
            if recv != Type::Any.new # XXX: should be configurable
              scratch.error(ep, "undefined method: #{ recv.strip_local_info(env).screen_name(scratch) }##{ mid }")
            end
            ep_then = ep.next
            ep_else = ep.jump(target)
            merge_env(ep_then, env)
            merge_env(ep_else, env)
          end
        end
        return
      when :invokeblock
        # XXX: need block parameter, unknown block, etc.
        blk = ep.ctx.sig.fargs.blk_ty
        case
        when blk.eql?(Type::Instance.new(Type::Builtin[:nil]))
          scratch.error(ep, "no block given")
          env = env.push(Type::Any.new)
        when blk.eql?(Type::Any.new)
          scratch.warn(ep, "block is any")
          env = env.push(Type::Any.new)
        else # Proc
          opt, = operands
          _flags = opt[:flag]
          orig_argc = opt[:orig_argc]
          env, aargs = env.pop(orig_argc)
          blk_nil = Type::Instance.new(Type::Builtin[:nil])
          aargs = ActualArguments.new(aargs, nil, blk_nil)
          Aux.do_invoke_block(true, ep.ctx.sig.fargs.blk_ty, aargs, ep, env, scratch)
          return
        end
      when :invokesuper
        env, recv, _, aargs = Aux.setup_actual_arguments(scratch, operands, ep, env)

        recv = ep.ctx.sig.recv_ty
        mid  = ep.ctx.sig.mid
        # XXX: need to support included module...
        meths = scratch.get_super_method(ep.ctx.cref.klass, mid) # TODO: multiple return values
        if meths
          meths.each do |meth|
            meth.do_send(self, flags, recv, mid, aargs, ep, env, scratch)
          end
          return
        else
          scratch.error(ep, "no superclass method: #{ ep.ctx.sig.recv_ty.screen_name(scratch) }##{ mid }")
          env = env.push(Type::Any.new)
        end
      when :invokebuiltin
        raise NotImplementedError
      when :leave
        if env.stack.size != 1
          raise "stack inconsistency error: #{ env.stack.inspect }"
        end
        env, (ty,) = env.pop(1)
        ty = ty.strip_local_info(env)
        scratch.add_return_type!(ep.ctx, ty)
        return
      when :throw
        raise NotImplementedError, "throw"
      when :once
        raise NotImplementedError, "once"

      when :branch # TODO: check how branchnil is used
        type, target, = operands
        # type: :if or :unless or :nil
        env, = env.pop(1)
        ep_then = ep.next
        ep_else = ep.jump(target)

        merge_env(ep_then, env)
        merge_env(ep_else, env)
        return
      when :jump
        target, = operands
        merge_env(ep.jump(target), env)
        return

      when :setinstancevariable
        var, = operands
        env, (ty,) = env.pop(1)
        recv = ep.ctx.sig.recv_ty
        ty = ty.strip_local_info(env)
        scratch.add_ivar_write!(recv, var, ty)

      when :getinstancevariable
        var, = operands
        recv = ep.ctx.sig.recv_ty
        # TODO: deal with inheritance?
        scratch.add_ivar_read!(recv, var, ep) do |ty, ep|
          nenv, ty = ty.deploy_local(env, ep)
          merge_env(ep.next, nenv.push(ty))
        end
        return

      when :getclassvariable
        raise NotImplementedError, "getclassvariable"
      when :setclassvariable
        raise NotImplementedError, "setclassvariable"

      when :setglobal
        var, = operands
        env, (ty,) = env.pop(1)
        ty = ty.strip_local_info(env)
        scratch.add_gvar_write!(var, ty)

      when :getglobal
        var, = operands
        scratch.add_gvar_read!(var, ep) do |ty, ep|
          nenv, ty = ty.deploy_local(env, ep)
          merge_env(ep.next, nenv.push(ty))
        end
        # need to return default nil of global variables
        return

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
        if cbase.eql?(Type::Instance.new(Type::Builtin[:nil]))
          ty = scratch.search_constant(ep.ctx.cref, name)
          env, ty = ty.deploy_local(env, ep) # TODO: multiple return arguments
          env = env.push(ty)
        elsif cbase.eql?(Type::Any.new)
          env = env.push(Type::Any.new) # XXX: warning needed?
        else
          ty = scratch.get_constant(cbase, name)
          env, ty = ty.deploy_local(env, ep) # TODO: multiple return arguments
          env = env.push(ty)
        end
      when :setconstant
        name, = operands
        env, (ty, cbase) = env.pop(2)
        old_ty = scratch.get_constant(cbase, name) # TODO: multiple return arguments
        if old_ty != Type::Any.new # XXX???
          scratch.warn(ep, "already initialized constant #{ Type::Instance.new(cbase).screen_name(scratch) }::#{ name }")
        end
        scratch.add_constant(cbase, name, ty.strip_local_info(env))

      when :getspecial
        key, type = operands
        if type == 0
          raise NotImplementedError
          case key
          when 0 # VM_SVAR_LASTLINE
            env = env.push(Type::Any.new) # or String | NilClass only?
          when 1 # VM_SVAR_BACKREF ($~)
            merge_env(ep.next, env.push(Type::Instance.new(Type::Builtin[:matchdata])))
            merge_env(ep.next, env.push(Type::Instance.new(Type::Builtin[:nil])))
            return
          else # flip-flop
            env = env.push(Type::Instance.new(Type::Builtin[:bool]))
          end
        else
          # NTH_REF ($1, $2, ...) / BACK_REF ($&, $+, ...)
          merge_env(ep.next, env.push(Type::Instance.new(Type::Builtin[:str])))
          merge_env(ep.next, env.push(Type::Instance.new(Type::Builtin[:nil])))
          return
        end
      when :setspecial
        # flip-flop
        raise NotImplementedError, "setspecial"

      when :dup
        env, (ty,) = env.pop(1)
        env = env.push(ty).push(ty)
      when :duphash
        env = env.push(Type::Any.new) # TODO: implement hash
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
        raise NotImplementedError, "defined"
      when :checkmatch
        flag, = operands
        array = flag & 4 != 0
        case flag & 3
        when 1
          raise NotImplementedError
        when 2 # VM_CHECKMATCH_TYPE_CASE
          raise NotImplementedError if array
          env, = env.pop(2)
          env = env.push(Type::Instance.new(Type::Builtin[:bool]))
        when 3
          raise NotImplementedError
        else
          raise "unknown checkmatch flag"
        end
      when :checkkeyword
        raise NotImplementedError, "checkkeyword"
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
        case ary
        when Type::LocalArray
          elems = env.get_array_elem_types(ary.id)
          elems ||= Type::Array::Seq.new(Utils::Set[Type::Any.new]) # XXX
          Aux.do_expand_array(self, ep, env, elems, num, splat, from_head)
          return
        when Type::Any
          splat = flag & 1 == 1
          num += 1 if splat
          num.times do
            env = env.push(Type::Any.new)
          end
        else
          # TODO: call to_ary (or to_a?)
          elems = Type::Array::Tuple.new(Utils::Set[ary.strip_local_info(env)])
          Aux.do_expand_array(self, ep, env, elems, num, splat, from_head)
          return
        end
      when :concatarray
        env, (ary1, ary2) = env.pop(2)
        if ary1.is_a?(Type::LocalArray)
          elems1 = env.get_array_elem_types(ary1.id)
          if ary2.is_a?(Type::LocalArray)
            elems2 = env.get_array_elem_types(ary2.id)
            elems = Type::Array::Seq.new(elems1.types + elems2.types)
            env = env.update_array_elem_types(ary1.id, elems)
            env = env.push(ary1)
          else
            elems = Type::Array::Seq.new(Utils::Set[Type::Any.new])
            env = env.update_array_elem_types(ary1.id, elems)
            env = env.push(ary1)
          end
        else
          ty = Type::Array.seq(Utils::Set[Type::Any.new])
          env, ty = ty.deploy_local(env, ep)
          env = env.push(ty)
        end

      when :checktype
        type, = operands
        raise NotImplementedError if type != 5 # T_STRING
        # XXX: is_a?
        env, (val,) = env.pop(1)
        res = val.strip_local_info(env) == Type::Instance.new(Type::Builtin[:str])
        ty = Type::Literal.new(res, Type::Instance.new(Type::Builtin[:bool]))
        env = env.push(ty)
      else
        raise "Unknown insn: #{ insn }"
      end

      add_edge(ep, ep)
      merge_env(ep.next, env)
    end

    module Aux
      module_function

      def do_expand_array(scratch, ep, env, elems, num, splat, from_head)
        if elems.is_a?(Type::Array::Tuple)
          elems = elems.elems
          if from_head
            # fetch num elements from the head
            if splat
              ty = Type::Array.tuple(elems[num..-1], Type::Instance.new(Type::Builtin[:ary]))
              env, ty = ty.deploy_local(env, ep)
              env = env.push(ty)
            end
            envs = [env]
            elems += [Utils::Set[Type::Instance.new(Type::Builtin[:nil])]] * (num - elems.size) if elems.size < num
            elems[0, num].reverse_each do |union|
              envs = envs.flat_map do |le|
                union.to_a.map do |ty|
                  ty = Type::Any.new if ty.is_a?(Type::Array) # XXX
                  if ty.is_a?(Type::Union) && ty.each.any? {|ty| ty.is_a?(Type::Array) }
                    ty = Type::Any.new # XXX
                  end
                  le.push(ty)
                end
              end
            end
          else
            # fetch num elements from the tail
            envs = [env]
            elems += [Utils::Set[Type::Instance.new(Type::Builtin[:nil])]] * (num - elems.size) if elems.size < num
            elems[-num..-1].reverse_each do |union|
              envs = envs.flat_map do |le|
                union.to_a.map do |ty|
                  ty = Type::Any.new if ty.is_a?(Type::Array) # XXX
                  if ty.is_a?(Type::Union) && ty.each.any? {|ty| ty.is_a?(Type::Array) }
                    ty = Type::Any.new # XXX
                  end
                  le.push(ty)
                end
              end
            end
            if splat
              ty = Type::Array.tuple(elems[0...-num], Type::Instance.new(Type::Builtin[:ary]))
              envs = envs.map do |lenv|
                lenv, local_ary_ty = ty.deploy_local(lenv, ep)
                lenv = lenv.push(local_ary_ty)
              end
            end
          end
          envs.each do |env|
            scratch.merge_env(ep.next, env)
          end
        else
          if from_head
            envs = [env]
            num.times do
              envs = envs.flat_map do |le|
                elems.types.to_a.map do |ty|
                  ty = Type::Any.new if ty.is_a?(Type::Array) # XXX
                  le.push(ty)
                end
              end
            end
            if splat
              envs = envs.map do |lenv|
                lenv, local_ary_ty = ty.deploy_local(lenv, ep)
                lenv = lenv.push(local_ary_ty)
              end
            end
          else
            envs = [env]
            if splat
              envs = envs.map do |lenv|
                lenv, local_ary_ty = ty.deploy_local(lenv, ep)
                lenv = lenv.push(local_ary_ty)
              end
            end
            num.times do
              envs = envs.flat_map do |le|
                elems.types.map do |ty|
                  ty = Type::Any.new if ty.is_a?(Type::Array) # XXX
                  le.push(ty)
                end
              end
            end
          end
          envs.each do |env|
            scratch.merge_env(ep.next, env)
          end
        end
      end

      def do_invoke_block(given_block, blk, aargs, ep, env, scratch, &ctn)
        if ctn
          do_invoke_block_core(given_block, blk, aargs, ep, env, scratch, &ctn)
        else
          do_invoke_block_core(given_block, blk, aargs, ep, env, scratch) do |ret_ty, ep, env|
            scratch.merge_env(ep.next, env.push(ret_ty))
          end
        end
      end

      def do_invoke_block_core(given_block, blk, aargs, ep, env, scratch, &ctn)
        blk_iseq = blk.iseq
        blk_ep = blk.ep
        blk_env = blk.env
        arg_blk = aargs.blk_ty
        aargs = aargs.lead_tys.map {|aarg| aarg.strip_local_info(env) }
        argc = blk_iseq.fargs_format[:lead_num] || 0
        if argc != aargs.size
          warn "complex parameter passing of block is not implemented"
          aargs.pop while argc < aargs.size
          aargs << Type::Any.new while argc > aargs.size
        end
        locals = [Type::Instance.new(Type::Builtin[:nil])] * blk_iseq.locals.size
        locals[blk_iseq.fargs_format[:block_start]] = arg_blk if blk_iseq.fargs_format[:block_start]
        recv = blk_ep.ctx.sig.recv_ty
        env_blk = blk_ep.ctx.sig.fargs.blk_ty
        nfargs = FormalArguments.new(aargs, [], nil, [], nil, env_blk) # XXX: aargs -> fargs
        nsig = Signature.new(recv, nil, nil, nfargs)
        nctx = Context.new(blk_iseq, blk_ep.ctx.cref, nsig)
        nep = ExecutionPoint.new(nctx, 0, blk_ep)
        nenv = Env.new(locals, [], {})
        alloc_site = AllocationSite.new(nep)
        aargs.each_with_index do |ty, i|
          alloc_site2 = alloc_site.add_id(i)
          nenv, ty = ty.deploy_local_core(nenv, alloc_site2)
          nenv = nenv.local_update(i, ty)
        end

        scratch.merge_env(nep, nenv)

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

        scratch.add_yield!(ep.ctx, nep.ctx) if given_block
        scratch.add_callsite!(nep.ctx, ep, env, &ctn)
      end

      def setup_actual_arguments(scratch, operands, ep, env)
        opt, blk_iseq = operands
        flags = opt[:flag]
        mid = opt[:mid]
        argc = opt[:orig_argc]
        argc += 1 # receiver
        # 1061     VM_CALL_ARGS_SPLAT_bit,     /* m(*args) */
        # 1062     VM_CALL_ARGS_BLOCKARG_bit,  /* m(&block) */
        # 1063     VM_CALL_FCALL_bit,          /* m(...) */
        # 1064     VM_CALL_VCALL_bit,          /* m */
        # 1065     VM_CALL_ARGS_SIMPLE_bit,    /* (ci->flag & (SPLAT|BLOCKARG)) && blockiseq == NULL && ci->kw_arg == NULL */
        # 1066     VM_CALL_BLOCKISEQ_bit,      /* has blockiseq */
        # 1067     VM_CALL_KWARG_bit,          /* has kwarg */
        # 1068     VM_CALL_KW_SPLAT_bit,       /* m(**opts) */
        # 1069     VM_CALL_TAILCALL_bit,       /* located at tail position */
        # 1070     VM_CALL_SUPER_bit,          /* super */
        # 1071     VM_CALL_ZSUPER_bit,         /* zsuper */
        # 1072     VM_CALL_OPT_SEND_bit,       /* internal flag */
        # 1073     VM_CALL__END

        #raise "call with splat is not supported yet" if flags[0] != 0
        #raise "call with splat is not supported yet" if flags[2] != 0
        splat = flags[0] != 0
        if flags[1] != 0 # VM_CALL_ARGS_BLOCKARG
          env, (recv, *aargs, blk_ty) = env.pop(argc + 1)
          raise "both block arg and actual block given" if blk_iseq
        else
          env, (recv, *aargs) = env.pop(argc)
          if blk_iseq
            # check
            blk_ty = Type::ISeqProc.new(blk_iseq, ep, env, Type::Instance.new(Type::Builtin[:proc]))
          else
            blk_ty = Type::Instance.new(Type::Builtin[:nil])
          end
        end
        case
        when blk_ty.eql?(Type::Instance.new(Type::Builtin[:nil]))
        when blk_ty.eql?(Type::Any.new)
        when blk_ty.is_a?(Type::ISeqProc)
        else
          scratch.error(ep, "wrong argument type #{ blk_ty.screen_name(scratch) } (expected Proc)")
          blk_ty = Type::Any.new
        end
        if flags[0] != 0 # VM_CALL_ARGS_SPLAT_bit
          aargs = ActualArguments.new(aargs[0..-2], aargs.last, blk_ty)
        else
          aargs = ActualArguments.new(aargs, nil, blk_ty)
        end
        return env, recv, mid, aargs
      end
    end
  end
end
