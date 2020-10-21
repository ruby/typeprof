require "optparse"
require "rbconfig"

module TypeProf
  class CLI
    DEFAULT_DIR_FILTER = [
      [:include],
      [:exclude, RbConfig::CONFIG["prefix"]],
      [:exclude, Gem.dir],
      [:exclude, Gem.user_dir],
    ]

    def initialize(argv)
      opt = OptionParser.new

      @output = nil

      # Verbose level:
      # * 0: no output
      # * 1: show indicator
      # * 2: debug print
      @verbose = 1

      @options = {
        type_depth_limit: 5,
        pedantic_output: false,
        show_errors: false,
        stackprof: nil,
      }
      @dir_filter = nil
      @rbs_features_to_load = []

      opt.on("-o OUTFILE") {|v| @output = v }
      opt.on("-q", "--quiet") { @verbose = 0 }
      opt.on("-v", "--verbose") { @options[:show_errors] = true }
      opt.on("-d", "--debug") { @verbose = 2 }
      opt.on("-I DIR") {|v| $LOAD_PATH << v }
      opt.on("-r FEATURE") {|v| @rbs_features_to_load << v }

      opt.on("--include-dir DIR") do |dir|
        # When `--include-dir` option is specified as the first directory option,
        # typeprof will exclude any files by default unless a file path matches the explicit option
        @dir_filter ||= [[:exclude]]
        @dir_filter << [:include, File.expand_path(dir)]
      end
      opt.on("--exclude-dir DIR") do |dir|
        # When `--exclude-dir` option is specified as the first directory option,
        # typeprof will include any files by default, except Ruby's install directory and Gem directories
        @dir_filter ||= DEFAULT_DIR_FILTER
        @dir_filter << [:exclude, File.expand_path(dir)]
      end

      opt.on("-f OPTION") do |v|
        key, args = v.split("=", 2)
        case key
        when "type-depth-limit"
          @options[:type_depth_limit] = Integer(args)
        when "pedantic-output"
          @options[:pedantic_output] = true
        when "show-errors"
          @options[:show_errors] = true
        when "show-container-raw-elements"
          @options[:show_container_raw_elements] = true
        when "stackprof"
          @options[:stackprof] = args ? args.to_sym : :cpu
        else
          raise OptionParser::InvalidOption.new("unknown option: #{ key }")
        end
      end

      opt.parse!(argv)

      @dir_filter ||= DEFAULT_DIR_FILTER
      @rb_files = []
      @rbs_files = []
      argv.each do |path|
        if File.extname(path) == ".rbs"
          @rbs_files << path
        else
          @rb_files << path
        end
      end

      raise OptionParser::InvalidOption.new("no input files") if @rb_files.empty?

      TypeProf.const_set(:Config, self)

    rescue OptionParser::InvalidOption
      puts $!
      exit
    end

    attr_reader :verbose, :options, :dir_filter
    attr_accessor :output

    def check_dir_filter(path)
      @dir_filter.reverse_each do |cond, dir|
        return cond unless dir
        return cond if path.start_with?(dir)
      end
    end

    def run
      if @options[:stackprof]
        require "stackprof"
        out = "typeprof-stackprof-#{ @options[:stackprof] }.dump"
        StackProf.start(mode: @options[:stackprof], out: out, raw: true)
      end

      scratch = Scratch.new
      Builtin.setup_initial_global_env(scratch)

      @rbs_features_to_load.each do |feature|
        Import.import_library(scratch, feature)
      end

      prologue_ctx = Context.new(nil, nil, nil)
      prologue_ep = ExecutionPoint.new(prologue_ctx, -1, nil)
      prologue_env = Env.new(StaticEnv.new(:top, Type.nil, false), [], [], Utils::HashWrapper.new({}))

      @rb_files.each do |path|
        if path == "-"
          iseq = ISeq.compile_str($<.read)
        else
          iseq = ISeq.compile(path)
        end
        ep, env = CLI.starting_state(iseq)
        scratch.merge_env(ep, env)
        scratch.add_callsite!(ep.ctx, nil, prologue_ep, prologue_env) {|ty, ep| }
      end

      @rbs_files.each do |path|
        Import.import_rbs_file(scratch, path)
      end

      result = scratch.type_profile

      if @output
        open(@output, "w") do |output|
          scratch.report(result, output)
        end
      else
        scratch.report(result, $stdout)
      end

    ensure
      if @options[:stackprof] && defined?(StackProf)
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
end
