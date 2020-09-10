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

    def self.run(name, code)
      new(name, code).run
    end

    def initialize(name, code)
      @name, @code = name, code
    end

    def run
      ENV["TP_SHOW_ERRORS"] = "1"
      ENV["TP_DETAILED_STUB"] = "1"
      $output = []
      verbose_back, $VERBOSE = $VERBOSE, nil

      iseq = TypeProfiler::ISeq.compile_str(@code, @name)
      buffer = DummyStdout.new
      TypeProfiler.type_profile(iseq, nil, buffer)

      buffer.result

    ensure
      ENV.delete("TP_SHOW_ERRORS")
      ENV.delete("TP_DETAILED_STUB")
      $output = nil
      $VERBOSE = verbose_back
    end
  end
end
