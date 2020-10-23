require "rbconfig"

module TypeProf
  ConfigData = Struct.new(
    :rb_files,
    :rbs_files,
    :output,
    :gem_rbs_features,
    :verbose,
    :dir_filter,
    :options,
    keyword_init: true
  )

  class ConfigData
    def initialize(**opt)
      opt[:output] ||= $stdout
      opt[:gem_rbs_features] ||= []
      opt[:dir_filter] ||= DEFAULT_DIR_FILTER
      opt[:verbose] ||= 0
      opt[:options] ||= {}
      opt[:options] = {
        type_depth_limit: 5,
        pedantic_output: false,
        show_errors: false,
        stackprof: nil,
      }.merge(opt[:options])
      super **opt
    end

    def check_dir_filter(path)
      dir_filter.reverse_each do |cond, dir|
        return cond unless dir
        return cond if path.start_with?(dir)
      end
    end

    DEFAULT_DIR_FILTER = [
      [:include],
      [:exclude, RbConfig::CONFIG["prefix"]],
      [:exclude, Gem.dir],
      [:exclude, Gem.user_dir],
    ]
  end

  def self.analyze(config)
    # Deploy the config to the TypeProf::Config (Note: This is thread unsafe)
    if TypeProf.const_defined?(:Config)
      TypeProf.send(:remove_const, :Config)
    end
    TypeProf.const_set(:Config, config)

    if Config.options[:stackprof]
      require "stackprof"
      out = "typeprof-stackprof-#{ Config.options[:stackprof] }.dump"
      StackProf.start(mode: Config.options[:stackprof], out: out, raw: true)
    end

    scratch = Scratch.new
    Builtin.setup_initial_global_env(scratch)

    Config.gem_rbs_features.each do |feature|
      Import.import_library(scratch, feature)
    end

    prologue_ctx = Context.new(nil, nil, nil)
    prologue_ep = ExecutionPoint.new(prologue_ctx, -1, nil)
    prologue_env = Env.new(StaticEnv.new(:top, Type.nil, false), [], [], Utils::HashWrapper.new({}))

    Config.rb_files.each do |file|
      if file.respond_to?(:read)
        iseq = ISeq.compile_str(file.read)
      else
        iseq = ISeq.compile(file)
      end
      ep, env = TypeProf.starting_state(iseq)
      scratch.merge_env(ep, env)
      scratch.add_callsite!(ep.ctx, nil, prologue_ep, prologue_env) {|ty, ep| }
    end

    Config.rbs_files.each do |path|
      Import.import_rbs_file(scratch, path)
    end

    result = scratch.type_profile

    if Config.output.respond_to?(:write)
      scratch.report(result, Config.output)
    else
      open(Config.output, "w") do |output|
        scratch.report(result, output)
      end
    end

  ensure
    if Config.options[:stackprof] && defined?(StackProf)
      StackProf.stop
      StackProf.results
    end
  end

  def self.starting_state(iseq)
    cref = CRef.new(:bottom, Type::Builtin[:obj], false) # object
    recv = Type::Instance.new(Type::Builtin[:obj])
    ctx = Context.new(iseq, cref, nil)
    ep = ExecutionPoint.new(ctx, 0, nil)
    locals = [Type.nil] * iseq.locals.size
    env = Env.new(StaticEnv.new(recv, Type.nil, false), locals, [], Utils::HashWrapper.new({}))

    return ep, env
  end
end
