require "simplecov"
SimpleCov.start do
  add_filter "rbs"
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

    def self.run(name, code, rbs_path: nil, **opt)
      new(name, code, rbs_path).run(**opt)
    end

    def initialize(name, code, rbs_path)
      @name, @code, @rbs_path = name, code, rbs_path
    end

    def run(show_errors: true, pedantic_output: true, show_progress: false)
      argv = [@name]
      argv << @rbs_path if @rbs_path
      argv << "-fshow-errors" if show_errors
      argv << "-fpedantic-output" if pedantic_output
      argv << "-q" unless show_progress
      verbose_back, $VERBOSE = $VERBOSE, nil

      cli = CLI.new(argv)
      Config.output = buffer = DummyStdout.new
      cli.run

      buffer.result

    ensure
      ENV.delete("TP_SHOW_ERRORS")
      ENV.delete("TP_DETAILED_STUB")
      $VERBOSE = verbose_back
    end
  end
end
