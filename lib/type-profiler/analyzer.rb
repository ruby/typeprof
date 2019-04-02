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

  class LocalEnv
    include Utils::StructuralEquality

    def initialize(ctx, pc, locals, stack, type_params, outer)
      @ctx = ctx
      @pc = pc
      @locals = locals
      @stack = stack
      @type_params = type_params
      @outer = outer
    end

    def site
      [@ctx, @pc]
    end

    attr_reader :ctx, :pc, :locals, :stack, :type_params, :outer

    def jump(pc)
      LocalEnv.new(@ctx, pc, @locals, @stack, @type_params, @outer)
    end

    def next
      jump(@pc + 1)
    end

    def push(*tys)
      tys.each do |ty|
        raise "Array cannot be pushed to the stack" if ty.is_a?(Type::Array)
        raise "nil cannot be pushed to the stack" if ty.nil?
      end
      LocalEnv.new(@ctx, @pc, @locals, @stack + tys, @type_params, @outer)
    end

    def pop(n)
      stack = @stack.dup
      tys = stack.pop(n)
      nlenv = LocalEnv.new(@ctx, @pc, @locals, stack, @type_params, @outer)
      return nlenv, tys
    end

    def setn(i, ty)
      stack = Utils.array_update(@stack, -i+0, ty)
      LocalEnv.new(@ctx, @pc, @locals, stack, @type_params, @outer)
    end

    def local_update(idx, scope, ty)
      if scope == 0
        LocalEnv.new(@ctx, @pc, Utils.array_update(@locals, idx, ty), @stack, @type_params, @outer)
      else
        LocalEnv.new(@ctx, @pc, @locals, @stack, @type_params, @outer.local_update(idx, scope - 1, ty))
      end
    end

    def deploy_type(ty, id)
      case ty
      when Type::Array
        if @type_params[site]
          local_ty = Type::LocalArray.new(site, ty.base_type)
          return self, local_ty, id
        else
          lenv = self
          lenv, elems, id = ty.elems.deploy_type(lenv, id)
          return lenv.deploy_array_type(ty.base_type, elems, id)
        end
      else
        return self, ty, id
      end
    end

    def deploy_array_type(base_ty, elems, id)
      local_ty = Type::LocalArray.new([site, id], base_ty)
      type_params = @type_params.merge({ [site, id] => elems })
      return LocalEnv.new(@ctx, @pc, @locals, @stack, type_params, @outer), local_ty, id + 1
    end

    def get_array_elem_types(id)
      @type_params[id]
    end

    def update_array_elem_types(id, idx, ty)
      elems = @type_params[id].update(idx, ty)
      type_params = @type_params.merge({ id => elems })
      LocalEnv.new(@ctx, @pc, @locals, @stack, type_params, @outer)
    end

    def location
      @ctx.iseq.source_location(@pc)
    end
  end

  class GlobalEnv
    include Utils::StructuralEquality

    # [Class]
    def initialize(class_defs)
      @class_defs = class_defs
    end

    def update_class(idx)
      klass = yield @class_defs[idx]
      GlobalEnv.new(Utils.array_update(@class_defs, idx, klass))
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
        return mthd if mthd
        idx = @class_defs[idx].superclass
      end
      nil
    end

    def get_singleton_method(klass, mid)
      idx = klass.idx
      while idx
        mthd = @class_defs[idx].get_singleton_method(mid)
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

    def new_class(klass, name, superclass)
      if klass.idx != 0
        class_name = "#{ @class_defs[klass.idx].name }::#{ name }"
      else
        class_name = name.to_s
      end
      idx = @class_defs.size
      nklass = Type::Class.new(idx, name)
      nclass_defs = @class_defs + [ClassDef.new(class_name, superclass.idx, {}, {}, {})]
      ngenv = GlobalEnv.new(nclass_defs).add_constant(klass, name, nklass)
      return ngenv, nklass
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
        update_class(klass.idx) do |klass_def|
          klass_def.add_constant(name, value)
        end
      end
    end

    def add_method(klass, mid, mdef)
      if klass == Type::Any.new
        self # XXX warn
      else
        update_class(klass.idx) do |klass_def|
          klass_def.add_method(mid, mdef)
        end
      end
    end

    def add_singleton_method(klass, mid, mdef)
      if klass == Type::Any.new
        self # XXX warn
      else
        update_class(klass.idx) do |klass_def|
          klass_def.add_singleton_method(mid, mdef)
        end
      end
    end

    def add_iseq_method(klass, mid, iseq, cref)
      add_method(klass, mid, ISeqMethodDef.new(iseq, cref, false))
    end

    def add_singleton_iseq_method(klass, mid, iseq, cref)
      add_singleton_method(klass, mid, ISeqMethodDef.new(iseq, cref, true))
    end

    def add_typed_method(recv_ty, mid, arg_tys, blk_ty, ret_ty)
      sig = Signature.new(recv_ty, false, mid, arg_tys, blk_ty)
      add_method(recv_ty.klass, mid, TypedMethodDef.new([[sig, ret_ty]]))
    end

    def add_singleton_typed_method(recv_ty, mid, arg_tys, blk_ty, ret_ty)
      sig = Signature.new(recv_ty, true, mid, arg_tys, blk_ty)
      add_singleton_method(recv_ty.klass, mid, TypedMethodDef.new([[sig, ret_ty]]))
    end

    def add_custom_method(klass, mid, impl)
      add_method(klass, mid, CustomMethodDef.new(impl))
    end

    def add_singleton_custom_method(klass, mid, impl)
      add_singleton_method(klass, mid, CustomMethodDef.new(impl))
      update_class(klass.idx) do |klass_def|
        klass_def.add_singleton_method(mid, CustomMethodDef.new(impl))
      end
    end

    def alias_method(klass, new, old)
      if klass == Type::Any.new
        self
      else
        update_class(klass.idx) do |klass_def|
          klass_def.add_method(new, klass_def.get_method(old))
        end
      end
    end
  end

  class Scratch
    def initialize
      @callsites = {}
      @signatures = {}
      @call_restarts = {}
      @ivar_sites = {}
      @ivar_types = {}
      @gvar_sites = {}
      @gvar_types = {}
      @yields = {}
      @new_states = []
      @next_state_table = {}
      @errors = []
      @backward_edges = {}
    end

    def add_edge(state, nstate)
      (@backward_edges[nstate] ||= {})[state] = true
    end

    class Restart
      def initialize(new_states)
        @new_states = new_states
        @continuations = []
        @restart_lenvs = {}
        @return_types = {}
      end

      def add_continuation(ctn, genv)
        @restart_lenvs.each_key do |lenv|
          @return_types.each_key do |ret_ty|
            @new_states << ctn[ret_ty, lenv, genv]
          end
        end
        @continuations << ctn
      end

      def add_restart_lenv(lenv, genv)
        return if @restart_lenvs[lenv]
        @continuations.each do |ctn|
          @return_types.each_key do |ret_ty|
            @new_states << ctn[ret_ty, lenv, genv]
          end
        end
        @restart_lenvs[lenv] = true
      end

      def add_return_type(ret_ty, genv)
        return if @return_types[ret_ty]
        @continuations.each do |ctn|
          @restart_lenvs.each_key do |lenv|
            @new_states << ctn[ret_ty, lenv, genv]
          end
        end
        @return_types[ret_ty] = true
      end
    end

    attr_reader :next_state_table, :new_states

    def add_callsite!(callee_ctx, caller_lenv, genv, &ctn)
      @callsites[callee_ctx] ||= {}
      @callsites[callee_ctx][caller_lenv.site] = true

      restart = @call_restarts[caller_lenv.site] ||= Restart.new(@new_states)
      restart.add_continuation(ctn, genv)
      restart.add_restart_lenv(caller_lenv, genv)

      @signatures[callee_ctx] ||= {}
      @signatures[callee_ctx].each_key do |ret_ty,|
        restart.add_return_type(ret_ty, genv)
      end
    end

    def add_return_lenv!(lenv, genv)
      restart = @call_restarts[lenv.site] ||= Restart.new(@new_states)
      restart.add_restart_lenv(lenv, genv)
    end

    def add_yield!(call_ctx, blk_ctx)
      @yields[call_ctx] ||= {}
      @yields[call_ctx][blk_ctx] = true
    end

    def add_return_type!(callee_ctx, ret_ty, genv)
      @callsites[callee_ctx] ||= {}

      key = [ret_ty, genv]
      @signatures[callee_ctx] ||= {}
      @signatures[callee_ctx][key] = true
      @callsites[callee_ctx].each_key do |lenv_site|
        restart = @call_restarts[lenv_site]
        restart.add_return_type(ret_ty, genv)
      end
    end

    def add_ivar_site!(recv, var, lenv, genv, &ctn)
      site = [recv, var]
      @ivar_sites[site] ||= {}
      unless @ivar_sites[site][lenv]
        @ivar_sites[site][lenv] = ctn
        if @ivar_types[site]
          @ivar_types[site].each_key do |ty,|
            @new_states << ctn[ty, genv]
          end
        else
          @new_states << ctn[Type::Instance.new(Type::Builtin[:nil]), genv]
        end
      end
    end

    def add_ivar_type!(recv, var, ty, genv, &ctn)
      site = [recv, var]
      @ivar_sites[site] ||= {}
      @ivar_types[site] ||= {}
      key = [ty, genv]
      unless @ivar_types[site][key]
        @ivar_types[site][key] = true
        @ivar_sites[site].each do |lenv, ctn|
          @new_states << ctn[ty, genv]
        end
      end
    end

    def add_gvar_site!(var, lenv, genv, &ctn)
      site = var
      @gvar_sites[site] ||= {}
      unless @gvar_sites[site][lenv]
        @gvar_sites[site][lenv] = ctn
        if @gvar_types[site]
          @gvar_types[site].each_key do |ty,|
            @new_states << ctn[ty, genv]
          end
        else
          @new_states << ctn[Type::Instance.new(Type::Builtin[:nil]), genv]
        end
      end
    end

    def add_gvar_type!(var, ty, genv, &ctn)
      site = var
      @gvar_sites[site] ||= {}
      @gvar_types[site] ||= {}
      key = [ty, genv]
      unless @gvar_types[site][key]
        @gvar_types[site][key] = true
        @gvar_sites[site].each do |lenv, ctn|
          @new_states << ctn[ty, genv]
        end
      end
    end

    def error(state, msg)
      p [show_code_pos(state.lenv), "[error] " + msg] if ENV["TP_DEBUG"]
      @errors << [state, "[error] " + msg]
    end

    def warn(state, msg)
      p [show_code_pos(state.lenv), "[warning] " + msg] if ENV["TP_DEBUG"]
      @errors << [state, "[warning] " + msg]
    end

    def show_signature(arg_tys, ret_tys)
      s = "(#{ arg_tys.join(", ") }) -> "
      s + (ret_tys.size == 1 ? ret_tys.first : "(#{ ret_tys.join(" | ") })")
    end

    def show_block(ctx, genv)
      blk_tys = {}
      @yields[ctx].each_key do |blk_ctx|
        blk_args = blk_ctx.sig.arg_tys.map {|ty| ty.screen_name(genv) }
        if @yields[blk_ctx]
          blk_args << show_block(blk_ctx, genv)
        end
        blk_rets = {}
        @signatures[blk_ctx].each_key do |blk_ret_ty, |
          blk_rets[blk_ret_ty.screen_name(genv)] = true
        end
        blk_tys["Proc[#{ show_signature(blk_args, blk_rets.keys) }]"] = true
      end
      blk_tys.size == 1 ? "&#{ blk_tys.keys.first }" : "&(#{ blk_tys.keys.join(" & ") })"
    end

    def generate_analysis_trace(state, visited)
      return nil if visited[state]
      visited[state] = true
      prev_states = @backward_edges[state]
      if prev_states
        prev_states.each_key do |pstate|
          trace = generate_analysis_trace(pstate, visited)
          return [state] + trace if trace
        end
        nil
      else
        []
      end
    end

    def filter_backtrace(trace)
      ntrace = [trace.first]
      trace.each_cons(2) do |state1, state2|
        ntrace << state2 if state1.lenv.ctx != state2.lenv.ctx
      end
      ntrace
    end

    def show_code_pos(lenv)
      path = lenv.ctx.iseq.path
      lineno = lenv.ctx.iseq.linenos[lenv.pc]
      [path, lineno]
    end

    def show(stat_states)
      out = []
      @errors.each do |state, msg|
        if ENV["TYPE_PROFILER_DETAIL"]
          backtrace = filter_backtrace(generate_analysis_trace(state, {}))
        else
          backtrace = [state]
        end
        (path, lineno), *backtrace = backtrace.map do |state|
          show_code_pos(state.lenv)
        end
        out << "#{ path }:#{ lineno }: #{ msg }"
        backtrace.each do |path, lineno|
          out << "        from #{ path }:#{ lineno }"
        end
      end
      h = {}
      @gvar_types.each do |var, tys|
        tys.each_key do |ty, genv|
          gvar_name = var
          ret = ty.screen_name(genv)
          h[gvar_name] ||= {}
          h[gvar_name][ret] ||= {}
        end
      end
      h.each do |gvar_name, tys|
        out << "#{ gvar_name } :: #{ tys.keys.join(" | ") }"
      end
      h = {}
      @ivar_types.each do |(recv, var), tys|
        tys.each_key do |ty, genv|
          ivar_name = "#{ recv.screen_name(genv) }##{ var }"
          ret = ty.screen_name(genv)
          h[ivar_name] ||= {}
          h[ivar_name][ret] ||= {}
        end
      end
      h.each do |ivar_name, tys|
        out << "#{ ivar_name } :: #{ tys.keys.join(" | ") }"
      end
      h = {}
      stat_classes = {}
      stat_methods = {}
      @signatures.each do |ctx, sigs|
        next unless ctx.sig.mid
        next unless ctx.iseq
        sigs.each_key do |ret_ty, genv|
          recv = ctx.cref.klass
          recv = Type::Instance.new(recv) unless ctx.sig.singleton
          recv = recv.screen_name(genv)
          stat_classes[recv] = true
          method_name = "#{ recv }##{ ctx.sig.mid }"
          stat_methods[method_name] = true
          args = ctx.sig.arg_tys.map {|ty| ty.screen_name(genv) }
          if @yields[ctx]
            args << show_block(ctx, genv)
          end
          ret = ret_ty.screen_name(genv)
          h[method_name] ||= {}
          h[method_name][args] ||= {}
          h[method_name][args][ret] = true
        end
      end
      h.each do |method_name, sigs|
        sigs.each do |args, rets|
          out << "#{ method_name } :: #{ show_signature(args, rets.keys) }"
        end
      end
      if ENV["TP_STAT"]
        puts "statistics:"
        puts "  %d states" % stat_states.size
        puts "  %d classes" % stat_classes.size
        puts "  %d methods (in total)" % stat_methods.size
      end
      if ENV["TP_COVERAGE"]
        coverage = {}
        stat_states.each_key do |s|
          path = s.lenv.ctx.iseq.path
          lineno = s.lenv.ctx.iseq.linenos[s.lenv.pc] - 1
          (coverage[path] ||= [])[lineno] ||= 0
          (coverage[path] ||= [])[lineno] += 1
        end
        File.binwrite("coverage.dump", Marshal.dump(coverage))
      end
      puts(*out)
    end
  end

  class State
    include Utils::StructuralEquality

    def initialize(lenv, genv)
      @lenv = lenv
      @genv = genv
    end

    attr_reader :lenv, :genv

    def self.run(state, scratch)
      visited = {}
      states = [state]
      counter = 0
      until states.empty?
        counter += 1
        if counter % 1000 == 0
          puts "iter %d, visited: %d, remain: %d" % [counter, visited.size, states.size]
        end
        state = states.pop
        next if !state
        unless visited[state]
          visited[state] = true
          new_states = scratch.new_states + state.run(scratch)
          scratch.new_states.clear
          new_states.each do |nstate|
            scratch.add_edge(state, nstate)
          end
          states += new_states
        end
      end
      visited
    end

    def run(scratch)
      scratch.next_state_table[self] ||= step(@lenv, @genv, scratch)
    end

    def step(lenv, genv, scratch)
      insn, *operands = lenv.ctx.iseq.insns[lenv.pc]

      p [lenv.location, lenv.pc, insn] if ENV["TP_DEBUG"]

      case insn
      when :putspecialobject
        type, = operands
        ty = case type
        when 1 then Type::Instance.new(Type::Builtin[:vmcore])
        when 2, 3 # CBASE / CONSTBASE
          lenv.ctx.cref.klass
        else
          raise NotImplementedError, "unknown special object: #{ type }"
        end
        lenv = lenv.push(ty)
      when :putnil
        lenv = lenv.push(Type::Instance.new(Type::Builtin[:nil]))
      when :putobject, :duparray
        obj, = operands
        lenv, ty, = lenv.deploy_type(Type.guess_literal_type(obj), 0)
        lenv = lenv.push(ty)
      when :putstring
        str, = operands
        ty = Type::Literal.new(str, Type::Instance.new(Type::Builtin[:str]))
        lenv = lenv.push(ty)
      when :putiseq
        iseq, = operands
        lenv = lenv.push(Type::ISeq.new(iseq))
      when :putself
        lenv = lenv.push(lenv.ctx.sig.recv_ty)
      when :newarray
        len, = operands
        lenv, elems = lenv.pop(len)
        ty = Type::Array.tuple(elems.map {|elem| Type::Union.new(elem) }, Type::Instance.new(Type::Builtin[:ary]))
        lenv, ty, = lenv.deploy_type(ty, 0)
        lenv = lenv.push(ty)
      when :newhash
        # XXX
        num, = operands
        lenv, = lenv.pop(num)
        lenv = lenv.push(Type::Any.new)
      when :newhashfromarray
        raise NotImplementedError, "newhashfromarray"
      when :newrange
        lenv, tys = lenv.pop(2)
        # XXX: need generics
        lenv = lenv.push(Type::Instance.new(Type::Builtin[:range]))

      when :concatstrings
        num, = operands
        lenv, = lenv.pop(num)
        lenv = lenv.push(Type::Instance.new(Type::Builtin[:str]))
      when :tostring
        lenv, (_ty1, _ty2,) = lenv.pop(2)
        lenv = lenv.push(Type::Instance.new(Type::Builtin[:str]))
      when :freezestring
        raise NotImplementedError, "freezestring"
      when :toregexp
        raise NotImplementedError, "toregexp"
      when :intern
        lenv, (ty,) = lenv.pop(1)
        # XXX check if ty is String
        lenv = lenv.push(Type::Instance.new(Type::Builtin[:sym]))

      when :defineclass
        id, iseq, flags = operands
        lenv, (cbase, superclass) = lenv.pop(2)
        case flags & 7
        when 0, 2 # CLASS / MODULE
          scratch.warn(self, "module is not supported yet") if flags & 7 == 2
          existing_klass = genv.get_constant(cbase, id)
          if existing_klass.is_a?(Type::Class)
            klass = existing_klass
          else
            if existing_klass != Type::Any.new
              scratch.error(self, "the class \"#{ id }\" is #{ existing_klass.screen_name(genv) }")
              id = :"#{ id }(dummy)"
            end
            existing_klass = genv.get_constant(cbase, id)
            if existing_klass != Type::Any.new
              klass = existing_klass
            else
              if superclass == Type::Any.new
                scratch.warn(self, "superclass is any; Object is used instead")
                superclass = Type::Builtin[:obj]
              elsif superclass.eql?(Type::Instance.new(Type::Builtin[:nil]))
                superclass = Type::Builtin[:obj]
              end
              genv, klass = genv.new_class(cbase, id, superclass)
            end
          end
        when 1 # SINGLETON_CLASS
          raise NotImplementedError
        else
          raise NotImplementedError, "unknown defineclass flag: #{ flags }"
        end
        ncref = lenv.ctx.cref.extend(klass)
        recv = klass
        blk = lenv.ctx.sig.blk_ty
        ctx = Context.new(iseq, ncref, Signature.new(recv, nil, nil, [], blk))
        nlenv = LocalEnv.new(ctx, 0, nil, [], {}, nil)
        state = State.new(nlenv, genv)
        scratch.add_callsite!(nlenv.ctx, lenv, genv) do |ret_ty, lenv, genv|
          nlenv = lenv.push(ret_ty).next
          State.new(nlenv, genv)
        end
        return [state]
      when :send
        lenv, recv, mid, args, blk = State.setup_arguments(operands, lenv)
        meth = recv.get_method(mid, genv)
        if meth
          return meth.do_send(self, flags, recv, mid, args, blk, lenv, genv, scratch)
        else
          if recv != Type::Any.new # XXX: should be configurable
            scratch.error(self, "undefined method: #{ recv.strip_local_info(lenv).screen_name(genv) }##{ mid }")
          end
          lenv = lenv.push(Type::Any.new)
        end
      when :invokeblock
        # XXX: need block parameter, unknown block, etc.
        blk = lenv.ctx.sig.blk_ty
        case
        when blk.eql?(Type::Instance.new(Type::Builtin[:nil]))
          scratch.error(self, "no block given")
          lenv = lenv.push(Type::Any.new)
        when blk.eql?(Type::Any.new)
          scratch.warn(self, "block is any")
          lenv = lenv.push(Type::Any.new)
        else # Proc
          opt, = operands
          _flags = opt[:flag]
          orig_argc = opt[:orig_argc]
          lenv, args = lenv.pop(orig_argc)
          blk_nil = Type::Instance.new(Type::Builtin[:nil])
          return State.do_invoke_block(true, lenv.ctx.sig.blk_ty, args, blk_nil, lenv, genv, scratch)
        end
      when :invokesuper
        lenv, recv, _, args, blk = State.setup_arguments(operands, lenv)

        recv = lenv.ctx.sig.recv_ty
        mid  = lenv.ctx.sig.mid
        # XXX: need to support included module...
        meth = genv.get_super_method(lenv.ctx.cref.klass, mid)
        if meth
          return meth.do_send(self, flags, recv, mid, args, blk, lenv, genv, scratch)
        else
          scratch.error(self, "no superclass method: #{ lenv.ctx.sig.recv_ty.screen_name(genv) }##{ mid }")
          lenv = lenv.push(Type::Any.new)
        end
      when :leave
        if lenv.stack.size != 1
          raise "stack inconsistency error: #{ lenv.stack.inspect }"
        end
        lenv, (ty,) = lenv.pop(1)
        ty = ty.strip_local_info(lenv)
        tmp_lenv = lenv
        while tmp_lenv.outer
          tmp_lenv = tmp_lenv.outer
          scratch.add_return_lenv!(tmp_lenv, genv)
        end
        scratch.add_return_type!(lenv.ctx, ty, genv)
        return []
      when :throw
        raise NotImplementedError, "throw"
      when :once
        raise NotImplementedError, "once"

      when :branchif, :branchunless, :branchnil # TODO: check how branchnil is used
        target, = operands
        lenv, = lenv.pop(1)
        lenv_t = lenv.next
        lenv_f = lenv.jump(target)
        return [
          State.new(lenv_t, genv),
          State.new(lenv_f, genv),
        ]
      when :jump
        target, = operands
        return [State.new(lenv.jump(target), genv)]

      when :setinstancevariable
        var, = operands
        lenv, (ty,) = lenv.pop(1)
        recv = lenv.ctx.sig.recv_ty
        ty = ty.strip_local_info(lenv)
        scratch.add_ivar_type!(recv, var, ty, genv)

      when :getinstancevariable
        var, = operands
        recv = lenv.ctx.sig.recv_ty
        scratch.add_ivar_site!(recv, var, lenv, genv) do |ty, genv|
          nlenv, ty, = lenv.deploy_type(ty, 0)
          nlenv = nlenv.push(ty).next
          State.new(nlenv, genv)
        end
        return []

      when :getclassvariable
        raise NotImplementedError, "getclassvariable"
      when :setclassvariable
        raise NotImplementedError, "setclassvariable"

      when :setglobal
        var, = operands
        lenv, (ty,) = lenv.pop(1)
        ty = ty.strip_local_info(lenv)
        scratch.add_gvar_type!(var, ty, genv)

      when :getglobal
        var, = operands
        scratch.add_gvar_site!(var, lenv, genv) do |ty, genv|
          nlenv = lenv.push(ty).next
          State.new(nlenv, genv)
        end
        return []

      when :getlocal, :getblockparam, :getblockparamproxy
        var_idx, scope_idx, _escaped = operands
        tmp_lenv = lenv
        scope_idx.times do
          tmp_lenv = tmp_lenv.outer
        end
        lenv = lenv.push(tmp_lenv.locals[-var_idx+2])
      when :setlocal, :setblockparam
        var_idx, scope_idx, _escaped = operands
        lenv, (ty,) = lenv.pop(1)
        lenv = lenv.local_update(-var_idx+2, scope_idx, ty)
      when :getconstant
        name, = operands
        lenv, (cbase,) = lenv.pop(1)
        if cbase.eql?(Type::Instance.new(Type::Builtin[:nil]))
          lenv = lenv.push(genv.search_constant(lenv.ctx.cref, name))
        elsif cbase.eql?(Type::Any.new)
          lenv = lenv.push(Type::Any.new) # XXX: warning needed?
        else
          #puts
          #p cbase, name
          lenv = lenv.push(genv.get_constant(cbase, name))
        end
      when :setconstant
        name, = operands
        lenv, (val, cbase) = lenv.pop(2)
        existing_val = genv.get_constant(cbase, name)
        if existing_val != Type::Any.new # XXX???
          scratch.warn(self, "already initialized constant #{ Type::Instance.new(cbase).screen_name(genv) }::#{ name }")
        end
        genv = genv.add_constant(cbase, name, val)

      when :getspecial
        key, type = operands
        if type == 0
          raise NotImplementedError
          case key
          when 0 # VM_SVAR_LASTLINE
            lenv = lenv.push(Type::Any.new) # or String | NilClass only?
          when 1 # VM_SVAR_BACKREF ($~)
            return [
              State.new(lenv.push(Type::Instance.new(Type::Builtin[:matchdata])).next, genv),
              State.new(lenv.push(Type::Instance.new(Type::Builtin[:nil])).next, genv),
            ]
          else # flip-flop
            lenv = lenv.push(Type::Instance.new(Type::Builtin[:bool]))
          end
        else
          # NTH_REF ($1, $2, ...) / BACK_REF ($&, $+, ...)
          return [
            State.new(lenv.push(Type::Instance.new(Type::Builtin[:str])).next, genv),
            State.new(lenv.push(Type::Instance.new(Type::Builtin[:nil])).next, genv),
          ]
        end
      when :setspecial
        # flip-flop
        raise NotImplementedError, "setspecial"

      when :dup
        lenv, (ty,) = lenv.pop(1)
        lenv = lenv.push(ty).push(ty)
      when :duphash
        lenv = lenv.push(Type::Any.new) # TODO: implement hash
      when :dupn
        n, = operands
        _, tys = lenv.pop(n)
        tys.each {|ty| lenv = lenv.push(ty) }
      when :pop
        lenv, = lenv.pop(1)
      when :swap
        raise NotImplementedError, "swap"
      when :reverse
        raise NotImplementedError, "reverse"
      when :topn
        raise NotImplementedError, "topn"
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
          lenv, = lenv.pop(2)
          lenv = lenv.push(Type::Instance.new(Type::Builtin[:bool]))
        when 3
          raise NotImplementedError
        else
          raise "unknown checkmatch flag"
        end
      when :checkkeyword
        raise NotImplementedError, "checkkeyword"
      when :adjuststack
        n, = operands
        lenv, _ = lenv.pop(n)
      when :nop
      when :setn
        idx, = operands
        lenv, (ty,) = lenv.pop(1)
        lenv = lenv.setn(idx, ty).push(ty)

      when :splatarray
        lenv, (ty,) = lenv.pop(1)
        # XXX: vm_splat_array
        lenv = lenv.push(ty)
      when :expandarray
        num, flag = operands
        lenv, (ary,) = lenv.pop(1)
        splat = flag & 1 == 1
        from_head = flag & 2 == 0
        case ary
        when Type::LocalArray
          elems = lenv.get_array_elem_types(ary.id)
          return do_expand_array(lenv, elems, num, splat, from_head)
        when Type::Any
          splat = flag & 1 == 1
          num += 1 if splat
          num.times do
            lenv = lenv.push(Type::Any.new)
          end
        else
          # TODO: call to_ary (or to_a?)
          elems = Type::Array::Tuple.new(Type::Union.new(ary.strip_local_info(lenv)))
          return do_expand_array(lenv, elems, num, splat, from_head)
        end
      when :concatarray
        raise NotImplementedError, "concatarray"

      when :checktype
        type, = operands
        raise NotImplementedError if type != 5 # T_STRING
        # XXX: is_a?
        lenv, (val,) = lenv.pop(1)
        res = val.strip_local_info(lenv) == Type::Instance.new(Type::Builtin[:str])
        ty = Type::Literal.new(res, Type::Instance.new(Type::Builtin[:bool]))
        lenv = lenv.push(ty)
      else
        raise NotImplementedError, "unknown insn: #{ insn }"
      end

      [State.new(lenv.next, genv)]
    end

    def do_expand_array(lenv, elems, num, splat, from_head)
      if elems.is_a?(Type::Array::Tuple)
        elems = elems.elems
        if from_head
          # fetch num elements from the head
          if splat
            ty = Type::Array.tuple(elems[num..-1], Type::Instance.new(Type::Builtin[:ary]))
            lenv, ty, = lenv.deploy_type(ty, 0)
            lenv = lenv.push(ty)
          end
          lenvs = [lenv]
          elems += [Type::Union.new(Type::Instance.new(Type::Builtin[:nil]))] * (num - elems.size) if elems.size < num
          elems[0, num].reverse_each do |union|
            lenvs = lenvs.flat_map do |le|
              union.types.map {|ty| le.push(ty) }
            end
          end
        else
          # fetch num elements from the tail
          lenvs = [lenv]
          elems += [Type::Union.new(Type::Instance.new(Type::Builtin[:nil]))] * (num - elems.size) if elems.size < num
          elems[-num..-1].reverse_each do |union|
            lenvs = lenvs.flat_map do |le|
              union.types.map {|ty| le.push(ty) }
            end
          end
          if splat
            ty = Type::Array.tuple(elems[0...-num], Type::Instance.new(Type::Builtin[:ary]))
            lenvs = lenvs.map do |le|
              id = 0
              le, local_ary_ty, id = le.deploy_type(ty, id)
              le = le.push(local_ary_ty)
            end
          end
        end
        return lenvs.map {|le| State.new(le.next, genv) }
      else
        if from_head
          lenvs = [lenv]
          num.times do
            lenvs = lenvs.flat_map do |le|
              elems.types.map {|ty| le.push(ty) }
            end
          end
          if splat
            lenvs = lenvs.map do |le|
              id = 0
              le, local_ary_ty, id = le.deploy_type(ty, id)
              le = le.push(local_ary_ty)
            end
          end
          return lenvs.map {|le| State.new(le.next, genv) }
        else
          lenvs = [lenv]
          if splat
            lenvs = lenvs.map do |le|
              id = 0
              le, local_ary_ty, id = le.deploy_type(ty, id)
              le = le.push(local_ary_ty)
            end
          end
          num.times do
            lenvs = lenvs.flat_map do |le|
              elems.types.map {|ty| le.push(ty) }
            end
          end
          return lenvs.map {|le| State.new(le.next, genv) }
        end
        raise NotImplementedError
      end
    end

    def self.do_invoke_block(given_block, blk, args, arg_blk, lenv, genv, scratch, &ctn)
      if ctn
        do_invoke_block_core(given_block, blk, args, arg_blk, lenv, genv, scratch, &ctn)
      else
        do_invoke_block_core(given_block, blk, args, arg_blk, lenv, genv, scratch) do |ret_ty, lenv, genv|
          nlenv = lenv.push(ret_ty).next
          State.new(nlenv, genv)
        end
      end
    end

    def self.do_invoke_block_core(given_block, blk, args, arg_blk, lenv, genv, scratch, &ctn)
      blk_iseq = blk.iseq
      blk_lenv = blk.lenv
      args = args.map {|arg| arg.strip_local_info(lenv) }
      argc = blk_iseq.args[:lead_num] || 0
      raise "complex parameter passing of block is not implemented" if argc != args.size
      locals = args + [Type::Instance.new(Type::Builtin[:nil])] * (blk_iseq.locals.size - args.size)
      locals[blk_iseq.args[:block_start]] = arg_blk if blk_iseq.args[:block_start]
      recv = blk_lenv.ctx.sig.recv_ty
      lenv_blk = blk_lenv.ctx.sig.blk_ty
      nctx = Context.new(blk_iseq, blk_lenv.ctx.cref, Signature.new(recv, nil, nil, args, lenv_blk))
      nlenv = LocalEnv.new(nctx, 0, locals, [], {}, blk_lenv)
      state = State.new(nlenv, genv)

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

      scratch.add_yield!(lenv.ctx, nlenv.ctx) if given_block
      scratch.add_callsite!(nlenv.ctx, lenv, genv, &ctn)
      return [state]
    end

    def State.setup_arguments(operands, lenv)
      opt, _, blk_iseq = operands
      flags = opt[:flag]
      mid = opt[:mid]
      argc = opt[:orig_argc]
      argc += 1 # receiver
      if flags & 2 != 0 # VM_CALL_ARGS_BLOCKARG
        lenv, (recv, *args, blk) = lenv.pop(argc + 1)
        raise "both block arg and actual block given" if blk_iseq
      else
        lenv, (recv, *args) = lenv.pop(argc)
        if blk_iseq
          # check
          blk = Type::ISeqProc.new(blk_iseq, lenv, Type::Instance.new(Type::Builtin[:proc]))
        else
          blk = Type::Instance.new(Type::Builtin[:nil])
        end
      end
      return lenv, recv, mid, args, blk
    end
  end
end
