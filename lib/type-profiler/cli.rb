require "optparse"

# # Run app.rb
# typeprof app.rb

# # Run app.rb with app.rbs
# typeprof app.rb app.rbs
# typeprof app.rbs app.rb

# # Run app.rb and test.rb
# typeprof app.rb test.rb

# # Run app.rb and output app.rbs
# typeprof -o app.rbs app.rb

# # Run app.rb with configuration
# typeprof app.rb -ftype-depth-limit=5

# # Output in pedantic format: `A | untyped` instead of `A`
# typeprof app.rb -fpedantic

# # Output errors
# typeprof app.rb -fshow-errors

# # Hide the progress indicator
# typeprof -q app.rb
# typeprof --quiet app.rb

# # Show a debug output
# typeprof -v app.rb
# typeprof -v app.rb

module TypeProfiler
  class CLI
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
      }

      opt.on("-o OUTFILE") {|v| @output = v }
      opt.on("-q", "--quiet") {|v| @verbose = 0 }
      opt.on("-v", "--verbose") {|v| @verbose = 2 }
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
        else
          raise OptionParser::InvalidOption.new("unknown option: #{ key }")
        end
      end

      opt.parse!(argv)

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

      TypeProfiler.const_set(:Config, self)

    rescue OptionParser::InvalidOption
      puts $!
      exit
    end

    attr_reader :verbose, :options, :files
    attr_accessor :output

    def run
      scratch = Scratch.new
      Builtin.setup_initial_global_env(scratch)

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
        RubySignatureImporter.import_rbs_file(scratch, path)
      end

      result = scratch.type_profile

      if @output
        open(@output, "w") do |output|
          scratch.report(result, output)
        end
      else
        scratch.report(result, $stdout)
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
