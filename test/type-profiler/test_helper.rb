require "simplecov"
SimpleCov.start do
  add_filter "rbs"
end

require "test-unit"

module TypeProfiler
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
    end

    def self.run(name, code, rbs_path: nil, **opt)
      new(name, code, rbs_path).run(**opt)
    end

    def initialize(name, code, rbs_path)
      @name, @code, @rbs_path = name, code, rbs_path
    end

    def run(show_errors: true, detailed_stub: true, show_progress: false)
      ENV["TP_SHOW_ERRORS"] = "1" if show_errors
      ENV["TP_DETAILED_STUB"] = "1" if detailed_stub
      ENV["TP_SHOW_PROGRESS"] = "1" if show_progress
      $output = []
      verbose_back, $VERBOSE = $VERBOSE, nil

      iseq = TypeProfiler::ISeq.compile_str(@code, @name)
      buffer = DummyStdout.new
      TypeProfiler.type_profile(iseq, @rbs_path, buffer)

      buffer.result

    ensure
      ENV.delete("TP_SHOW_ERRORS")
      ENV.delete("TP_DETAILED_STUB")
      $output = nil
      $VERBOSE = verbose_back
    end
  end
end
