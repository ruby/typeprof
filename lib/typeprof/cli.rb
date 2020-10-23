require "optparse"

module TypeProf
  module CLI
    module_function

    def parse(argv)
      opt = OptionParser.new

      output = nil

      # Verbose level:
      # * 0: no output
      # * 1: show indicator
      # * 2: debug print
      verbose = 1

      options = {}
      dir_filter = nil
      gem_rbs_features = []
      version = false

      opt.on("-o OUTFILE") {|v| output = v }
      opt.on("-q", "--quiet") { verbose = 0 }
      opt.on("-v", "--verbose") { options[:show_errors] = true }
      opt.on("--version") { version = true }
      opt.on("-d", "--debug") { verbose = 2 }
      opt.on("-I DIR") {|v| $LOAD_PATH << v }
      opt.on("-r FEATURE") {|v| gem_rbs_features << v }

      opt.on("--include-dir DIR") do |dir|
        # When `--include-dir` option is specified as the first directory option,
        # typeprof will exclude any files by default unless a file path matches the explicit option
        dir_filter ||= [[:exclude]]
        dir_filter << [:include, File.expand_path(dir)]
      end
      opt.on("--exclude-dir DIR") do |dir|
        # When `--exclude-dir` option is specified as the first directory option,
        # typeprof will include any files by default, except Ruby's install directory and Gem directories
        dir_filter ||= ConfigData::DEFAULT_DIR_FILTER
        dir_filter << [:exclude, File.expand_path(dir)]
      end

      opt.on("-f OPTION") do |v|
        key, args = v.split("=", 2)
        case key
        when "type-depth-limit"
          options[:type_depth_limit] = Integer(args)
        when "pedantic-output"
          options[:pedantic_output] = true
        when "show-errors"
          options[:show_errors] = true
        when "show-container-raw-elements"
          options[:show_container_raw_elements] = true
        when "stackprof"
          options[:stackprof] = args ? args.to_sym : :cpu
        else
          raise OptionParser::InvalidOption.new("unknown option: #{ key }")
        end
      end

      opt.parse!(argv)

      dir_filter ||= ConfigData::DEFAULT_DIR_FILTER
      rb_files = []
      rbs_files = []
      argv.each do |path|
        if File.extname(path) == ".rbs"
          rbs_files << path
        else
          rb_files << path
        end
      end

      puts "typeprof #{ VERSION }" if version
      if rb_files.empty?
        exit if version
        raise OptionParser::InvalidOption.new("no input files")
      end

      config = ConfigData.new(
        rb_files: rb_files,
        rbs_files: rbs_files,
        output: output,
        gem_rbs_features: gem_rbs_features,
        verbose: verbose,
        dir_filter: dir_filter,
        options: options,
      )

    rescue OptionParser::InvalidOption
      puts $!
      exit
    end
  end
end
