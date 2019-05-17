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

    attr_reader :ctx, :pc, :outer

    def jump(pc)
      ExecutionPoint.new(@ctx, pc, @outer)
    end

    def source_location
      @ctx.iseq.source_location(@pc)
    end
  end

  class LocalEnv
    include Utils::StructuralEquality

    def initialize(ep, locals, stack, type_params, outer)
      @ep = ep
      @locals = locals
      @stack = stack
      @type_params = type_params
      @outer = outer
    end

    attr_reader :ep, :locals, :stack, :type_params, :outer

    def jump(pc)
      LocalEnv.new(@ep.jump(pc), @locals, @stack, @type_params, @outer)
    end

    def next
      jump(@ep.pc + 1)
    end

    def push(*tys)
      tys.each do |ty|
        raise "Array cannot be pushed to the stack" if ty.is_a?(Type::Array)
        raise "nil cannot be pushed to the stack" if ty.nil?
      end
      LocalEnv.new(@ep, @locals, @stack + tys, @type_params, @outer)
    end

    def pop(n)
      stack = @stack.dup
      tys = stack.pop(n)
      nlenv = LocalEnv.new(@ep, @locals, stack, @type_params, @outer)
      return nlenv, tys
    end

    def setn(i, ty)
      stack = Utils.array_update(@stack, -i, ty)
      LocalEnv.new(@ep, @locals, stack, @type_params, @outer)
    end

    def topn(i)
      push(@stack[-i - 1])
    end

    def local_update(idx, scope, ty)
      if scope == 0
        LocalEnv.new(@ep, Utils.array_update(@locals, idx, ty), @stack, @type_params, @outer)
      else
        LocalEnv.new(@ep, @locals, @stack, @type_params, @outer.local_update(idx, scope - 1, ty))
      end
    end

    def deploy_type(ty, id)
      case ty
      when Type::Array
        if @type_params[@ep]
          local_ty = Type::LocalArray.new(@ep, ty.base_type)
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
      local_ty = Type::LocalArray.new([@ep, id], base_ty)

      type_params = @type_params.merge({ [@ep, id] => elems })
      nlenv = LocalEnv.new(@ep, @locals, @stack, type_params, @outer)
      #p [location, @ep.pc, :merge, self.hash, nlenv.hash, @type_params[[@ep, id]]]
      return nlenv, local_ty, id + 1
    end

    def get_array_elem_types(id)
      @type_params[id] || @outer.get_array_elem_types(id)
    end

    def update_array_elem_types(id, idx, ty)
      type_param = @type_params[id]
      if type_param
        elems = @type_params[id].update(idx, ty)
        type_params = @type_params.merge({ id => elems })
        LocalEnv.new(@ep, @locals, @stack, type_params, @outer)
      else
        nouter = @outer.update_array_elem_types(id, idx, ty)
        LocalEnv.new(@ep, @locals, @stack, @type_params, nouter)
      end
    end

    def location
      @ep.source_location
    end
  end

  class Scratch
    def initialize
      @class_defs = {}

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

      def add_continuation(ctn)
        @restart_lenvs.each_key do |lenv|
          @return_types.each_key do |ret_ty|
            @new_states << ctn[ret_ty, lenv]
          end
        end
        @continuations << ctn
      end

      def add_restart_lenv(lenv)
        return if @restart_lenvs[lenv]
        @continuations.each do |ctn|
          @return_types.each_key do |ret_ty|
            @new_states << ctn[ret_ty, lenv]
          end
        end
        @restart_lenvs[lenv] = true
      end

      def add_return_type(ret_ty)
        return if @return_types[ret_ty]
        @continuations.each do |ctn|
          @restart_lenvs.each_key do |lenv|
            @new_states << ctn[ret_ty, lenv]
          end
        end
        @return_types[ret_ty] = true
      end
    end

    attr_reader :next_state_table, :new_states

    def add_callsite!(callee_ctx, caller_lenv, &ctn)
      @callsites[callee_ctx] ||= {}
      @callsites[callee_ctx][caller_lenv.ep] = true

      restart = @call_restarts[caller_lenv.ep] ||= Restart.new(@new_states)
      restart.add_continuation(ctn)
      restart.add_restart_lenv(caller_lenv)

      @signatures[callee_ctx] ||= {}
      @signatures[callee_ctx].each_key do |ret_ty,|
        restart.add_return_type(ret_ty)
      end
    end

    def add_return_lenv!(lenv)
      restart = @call_restarts[lenv.ep] ||= Restart.new(@new_states)
      restart.add_restart_lenv(lenv)
    end

    def add_yield!(call_ctx, blk_ctx)
      @yields[call_ctx] ||= {}
      @yields[call_ctx][blk_ctx] = true
    end

    def add_return_type!(callee_ctx, ret_ty)
      @callsites[callee_ctx] ||= {}

      key = ret_ty
      @signatures[callee_ctx] ||= {}
      @signatures[callee_ctx][key] = true
      @callsites[callee_ctx].each_key do |lenv_site|
        restart = @call_restarts[lenv_site]
        restart.add_return_type(ret_ty)
      end
    end

    def add_ivar_site!(recv, var, lenv, &ctn)
      site = [recv, var]
      @ivar_sites[site] ||= {}
      unless @ivar_sites[site][lenv]
        @ivar_sites[site][lenv] = ctn
        if @ivar_types[site]
          @ivar_types[site].each_key do |ty,|
            @new_states << ctn[ty]
          end
        else
          @new_states << ctn[Type::Instance.new(Type::Builtin[:nil])]
        end
      end
    end

    def add_ivar_type!(recv, var, ty, &ctn)
      site = [recv, var]
      @ivar_sites[site] ||= {}
      @ivar_types[site] ||= {}
      unless @ivar_types[site][ty]
        @ivar_types[site][ty] = true
        @ivar_sites[site].each do |lenv, ctn|
          @new_states << ctn[ty]
        end
      end
    end

    def add_gvar_site!(var, lenv, &ctn)
      site = var
      @gvar_sites[site] ||= {}
      unless @gvar_sites[site][lenv]
        @gvar_sites[site][lenv] = ctn
        if @gvar_types[site]
          @gvar_types[site].each_key do |ty,|
            @new_states << ctn[ty]
          end
        else
          @new_states << ctn[Type::Instance.new(Type::Builtin[:nil])]
        end
      end
    end

    def add_gvar_type!(var, ty, &ctn)
      site = var
      @gvar_sites[site] ||= {}
      @gvar_types[site] ||= {}
      unless @gvar_types[site][ty]
        @gvar_types[site][ty] = true
        @gvar_sites[site].each do |lenv, ctn|
          @new_states << ctn[ty]
        end
      end
    end

    def error(state, msg)
      p [state.lenv.location, "[error] " + msg] if ENV["TP_DEBUG"]
      @errors << [state, "[error] " + msg]
    end

    def warn(state, msg)
      p [state.lenv.location, "[warning] " + msg] if ENV["TP_DEBUG"]
      @errors << [state, "[warning] " + msg]
    end

    def reveal_type(state, msg)
      p [state.lenv.location, "[p] " + msg] if ENV["TP_DEBUG"]
      @errors << [state, "[p] " + msg]
    end

    def show_signature(arg_tys, ret_tys)
      s = "(#{ arg_tys.join(", ") }) -> "
      s + (ret_tys.size == 1 ? ret_tys.first : "(#{ ret_tys.join(" | ") })")
    end

    def show_block(ctx)
      blk_tys = {}
      @yields[ctx].each_key do |blk_ctx|
        blk_args = blk_ctx.sig.arg_tys.map {|ty| ty.screen_name(self) }
        if @yields[blk_ctx]
          blk_args << show_block(blk_ctx)
        end
        blk_rets = {}
        @signatures[blk_ctx].each_key do |blk_ret_ty|
          blk_rets[blk_ret_ty.screen_name(self)] = true
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
        ntrace << state2 if state1.lenv.ep.ctx != state2.lenv.ep.ctx
      end
      ntrace
    end

    def show(stat_states)
      out = []
      @errors.each do |state, msg|
        if ENV["TYPE_PROFILER_DETAIL"]
          backtrace = filter_backtrace(generate_analysis_trace(state, {}))
        else
          backtrace = [state]
        end
        loc, *backtrace = backtrace.map do |state|
          state.lenv.location
        end
        out << "#{ loc }: #{ msg }"
        backtrace.each do |loc|
          out << "        from #{ loc }"
        end
      end
      h = {}
      @gvar_types.each do |var, tys|
        tys.each_key do |ty|
          gvar_name = var
          ret = ty.screen_name(self)
          h[gvar_name] ||= {}
          h[gvar_name][ret] ||= {}
        end
      end
      h.each do |gvar_name, tys|
        out << "#{ gvar_name } :: #{ tys.keys.join(" | ") }"
      end
      h = {}
      @ivar_types.each do |(recv, var), tys|
        tys.each_key do |ty|
          ivar_name = "#{ recv.screen_name(self) }##{ var }"
          ret = ty.screen_name(self)
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
        sigs.each_key do |ret_ty|
          method_count = 0
          @class_defs.each do |class_def|
            #p [class_def.name, class_def.methods.keys.size]
            method_count += class_def.methods.size
          end
          #p method_count
          recv = ctx.cref.klass
          recv = Type::Instance.new(recv) unless ctx.sig.singleton
          recv = recv.screen_name(self)
          stat_classes[recv] = true
          method_name = "#{ recv }##{ ctx.sig.mid }"
          stat_methods[method_name] = true
          args = ctx.sig.arg_tys.map {|ty| ty.screen_name(self) }
          if @yields[ctx]
            args << show_block(ctx)
          end
          ret = ret_ty.screen_name(self)
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
          path = s.lenv.ep.ctx.iseq.path
          lineno = s.lenv.ep.ctx.iseq.linenos[s.lenv.pc] - 1
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

    def initialize(lenv)
      @lenv = lenv
    end

    attr_reader :lenv

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
      scratch.next_state_table[self] ||= step(@lenv, scratch)
    end

    def step(lenv, scratch)
      insn, *operands = lenv.ep.ctx.iseq.insns[lenv.ep.pc]

      p [lenv.location, lenv.ep.pc, insn, lenv.stack.size] if ENV["TP_DEBUG"]

      case insn
      when :putspecialobject
        type, = operands
        ty = case type
        when 1 then Type::Instance.new(Type::Builtin[:vmcore])
        when 2, 3 # CBASE / CONSTBASE
          lenv.ep.ctx.cref.klass
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
        lenv = lenv.push(lenv.ep.ctx.sig.recv_ty)
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
          existing_klass = scratch.get_constant(cbase, id) # TODO: multiple return values
          if existing_klass.is_a?(Type::Class)
            klass = existing_klass
          else
            if existing_klass != Type::Any.new
              scratch.error(self, "the class \"#{ id }\" is #{ existing_klass.screen_name(scratch) }")
              id = :"#{ id }(dummy)"
            end
            existing_klass = scratch.get_constant(cbase, id) # TODO: multiple return values
            if existing_klass != Type::Any.new
              klass = existing_klass
            else
              if superclass == Type::Any.new
                scratch.warn(self, "superclass is any; Object is used instead")
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
        ncref = lenv.ep.ctx.cref.extend(klass)
        recv = klass
        blk = lenv.ep.ctx.sig.blk_ty
        ctx = Context.new(iseq, ncref, Signature.new(recv, nil, nil, [], blk))
        ep = ExecutionPoint.new(ctx, 0, nil)
        nlenv = LocalEnv.new(ep, nil, [], {}, nil)
        state = State.new(nlenv)
        scratch.add_callsite!(nlenv.ep.ctx, lenv) do |ret_ty, lenv|
          nlenv = lenv.push(ret_ty).next
          State.new(nlenv)
        end
        return [state]
      when :send
        lenv, recv, mid, args, blk = State.setup_arguments(operands, lenv)
        meths = recv.get_method(mid, scratch)
        if meths
          return meths.flat_map do |meth|
            meth.do_send(self, flags, recv, mid, args, blk, lenv, scratch)
          end
        else
          if recv != Type::Any.new # XXX: should be configurable
            scratch.error(self, "undefined method: #{ recv.strip_local_info(lenv).screen_name(scratch) }##{ mid }")
          end
          lenv = lenv.push(Type::Any.new)
        end
      when :invokeblock
        # XXX: need block parameter, unknown block, etc.
        blk = lenv.ep.ctx.sig.blk_ty
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
          return State.do_invoke_block(true, lenv.ep.ctx.sig.blk_ty, args, blk_nil, lenv, scratch)
        end
      when :invokesuper
        lenv, recv, _, args, blk = State.setup_arguments(operands, lenv)

        recv = lenv.ep.ctx.sig.recv_ty
        mid  = lenv.ep.ctx.sig.mid
        # XXX: need to support included module...
        meths = scratch.get_super_method(lenv.ep.ctx.cref.klass, mid) # TODO: multiple return values
        if meths
          return meths.flat_map do |meth|
            meth.do_send(self, flags, recv, mid, args, blk, lenv, scratch)
          end
        else
          scratch.error(self, "no superclass method: #{ lenv.ep.ctx.sig.recv_ty.screen_name(scratch) }##{ mid }")
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
          scratch.add_return_lenv!(tmp_lenv)
        end
        scratch.add_return_type!(lenv.ep.ctx, ty)
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
          State.new(lenv_t),
          State.new(lenv_f),
        ]
      when :jump
        target, = operands
        return [State.new(lenv.jump(target))]

      when :setinstancevariable
        var, = operands
        lenv, (ty,) = lenv.pop(1)
        recv = lenv.ep.ctx.sig.recv_ty
        ty = ty.strip_local_info(lenv)
        scratch.add_ivar_type!(recv, var, ty)

      when :getinstancevariable
        var, = operands
        recv = lenv.ep.ctx.sig.recv_ty
        scratch.add_ivar_site!(recv, var, lenv) do |ty|
          nlenv, ty, = lenv.deploy_type(ty, 0)
          nlenv = nlenv.push(ty).next
          State.new(nlenv)
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
        scratch.add_gvar_type!(var, ty)

      when :getglobal
        var, = operands
        scratch.add_gvar_site!(var, lenv) do |ty|
          nlenv = lenv.push(ty).next
          State.new(nlenv)
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
          lenv, ty, = lenv.deploy_type(scratch.search_constant(lenv.ep.ctx.cref, name), 0) # TODO: multiple return arguments
          lenv = lenv.push(ty)
        elsif cbase.eql?(Type::Any.new)
          lenv = lenv.push(Type::Any.new) # XXX: warning needed?
        else
          #puts
          #p cbase, name
          lenv, ty, = lenv.deploy_type(scratch.get_constant(cbase, name), 0) # TODO: multiple return arguments
          lenv = lenv.push(ty)
        end
      when :setconstant
        name, = operands
        lenv, (val, cbase) = lenv.pop(2)
        existing_val = scratch.get_constant(cbase, name) # TODO: multiple return arguments
        if existing_val != Type::Any.new # XXX???
          scratch.warn(self, "already initialized constant #{ Type::Instance.new(cbase).screen_name(scratch) }::#{ name }")
        end
        scratch.add_constant(cbase, name, val.strip_local_info(lenv))

      when :getspecial
        key, type = operands
        if type == 0
          raise NotImplementedError
          case key
          when 0 # VM_SVAR_LASTLINE
            lenv = lenv.push(Type::Any.new) # or String | NilClass only?
          when 1 # VM_SVAR_BACKREF ($~)
            return [
              State.new(lenv.push(Type::Instance.new(Type::Builtin[:matchdata])).next),
              State.new(lenv.push(Type::Instance.new(Type::Builtin[:nil])).next),
            ]
          else # flip-flop
            lenv = lenv.push(Type::Instance.new(Type::Builtin[:bool]))
          end
        else
          # NTH_REF ($1, $2, ...) / BACK_REF ($&, $+, ...)
          return [
            State.new(lenv.push(Type::Instance.new(Type::Builtin[:str])).next),
            State.new(lenv.push(Type::Instance.new(Type::Builtin[:nil])).next),
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
      when :topn
        idx, = operands
        lenv = lenv.topn(idx)

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

      [State.new(lenv.next)]
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
        return lenvs.map {|le| State.new(le.next) }
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
          return lenvs.map {|le| State.new(le.next) }
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
          return lenvs.map {|le| State.new(le.next) }
        end
        raise NotImplementedError
      end
    end

    def self.do_invoke_block(given_block, blk, args, arg_blk, lenv, scratch, &ctn)
      if ctn
        do_invoke_block_core(given_block, blk, args, arg_blk, lenv, scratch, &ctn)
      else
        do_invoke_block_core(given_block, blk, args, arg_blk, lenv, scratch) do |ret_ty, lenv|
          nlenv = lenv.push(ret_ty).next
          State.new(nlenv)
        end
      end
    end

    def self.do_invoke_block_core(given_block, blk, args, arg_blk, lenv, scratch, &ctn)
      blk_iseq = blk.iseq
      blk_lenv = blk.lenv
      args = args.map {|arg| arg.strip_local_info(lenv) }
      argc = blk_iseq.args[:lead_num] || 0
      raise "complex parameter passing of block is not implemented" if argc != args.size
      locals = args + [Type::Instance.new(Type::Builtin[:nil])] * (blk_iseq.locals.size - args.size)
      locals[blk_iseq.args[:block_start]] = arg_blk if blk_iseq.args[:block_start]
      recv = blk_lenv.ep.ctx.sig.recv_ty
      lenv_blk = blk_lenv.ep.ctx.sig.blk_ty
      nctx = Context.new(blk_iseq, blk_lenv.ep.ctx.cref, Signature.new(recv, nil, nil, args, lenv_blk))
      nep = ExecutionPoint.new(nctx, 0, blk_lenv.ep)
      nlenv = LocalEnv.new(nep, locals, [], {}, blk_lenv)
      state = State.new(nlenv)

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

      scratch.add_yield!(lenv.ep.ctx, nlenv.ep.ctx) if given_block
      scratch.add_callsite!(nlenv.ep.ctx, lenv, &ctn)
      return [state]
    end

    def State.setup_arguments(operands, lenv)
      opt, _, blk_iseq = operands
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
      if flags[1] != 0 # VM_CALL_ARGS_BLOCKARG
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
