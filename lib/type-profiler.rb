require_relative "type-profiler/insns-def"
require_relative "type-profiler/utils"
require_relative "type-profiler/type"
require_relative "type-profiler/method"
require_relative "type-profiler/iseq"
require_relative "type-profiler/analyzer"
require_relative "type-profiler/builtin"

module TypeProfiler
  def self.type_profile(iseq)
    # TODO: resolve file path
    genv = setup_initial_global_env
    scratch = Scratch.new
    state = starting_state(iseq, genv)
    dummy_ctx = Context.new(nil, nil, Signature.new(:top, nil, nil, [], nil))
    dummy_lenv = LocalEnv.new(dummy_ctx, -1, [], [], {}, nil)
    scratch.add_callsite!(state.lenv.ctx, dummy_lenv, genv) do |ret_ty, lenv, genv|
      #p :genv
      nil
    end
    scratch.show(State.run(state, scratch))
  end

  def self.starting_state(iseq, genv)
    cref = CRef.new(:bottom, Type::Builtin[:obj]) # object
    recv = Type::Instance.new(Type::Builtin[:obj])
    _nil = Type::Instance.new(Type::Builtin[:nil])
    ctx = Context.new(iseq, cref, Signature.new(recv, nil, nil, [], _nil))
    locals = [_nil] * (iseq.locals.size + 1)
    lenv = LocalEnv.new(ctx, 0, locals, [], {}, nil)

    State.new(lenv, genv)
  end
end
