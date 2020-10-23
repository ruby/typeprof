begin
  require "simplecov"
  SimpleCov.start do
    add_filter "rbs"
  end
rescue LoadError
end

require "test-unit"

module TypeProf
  class TestRun
    class DummyStdout
      def initialize
        @buffer = []
      end

      def puts(s = nil)
        @buffer << (s ? s + "\n" : "\n")
      end

      def result
        @buffer.join
      end

      def to_open(*)
        self
      end
    end

    def self.run(name, rbs_path: nil, **opt)
      new(name, rbs_path).run(**opt)
    end

    def initialize(name, rbs_path)
      @name, @rbs_path = name, rbs_path
    end

    def run(show_errors: true, pedantic_output: true, show_progress: false, stackprof: nil)
      argv = [@name]
      argv << @rbs_path if @rbs_path
      argv << "-fshow-errors" if show_errors
      argv << "-fpedantic-output" if pedantic_output
      argv << "-fstackprof=#{ stackprof }" if stackprof
      argv << "-q" unless show_progress
      verbose_back, $VERBOSE = $VERBOSE, nil

      config = CLI.parse(argv)
      config.output = buffer = DummyStdout.new
      TypeProf.analyze(config)

      buffer.result

    ensure
      ENV.delete("TP_SHOW_ERRORS")
      ENV.delete("TP_DETAILED_STUB")
      $VERBOSE = verbose_back
    end

    def self.setup_testbed_repository(dir, github_repo_url, revision)
      dir = File.join(__dir__, "../../testbed/", dir)
      unless File.directory?(dir)
        Dir.mkdir(dir)
        system("git", "init", chdir: dir, exception: true)
        system("git", "remote", "add", "origin", github_repo_url, chdir: dir, exception: true)
        system("git", "fetch", "origin", revision, chdir: dir, exception: true)
      end
      system("git", "reset", "--quiet", "--hard", revision, chdir: dir, exception: true)

      true
    rescue Errno::ENOENT
      false
    end
  end
end
