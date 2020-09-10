require_relative "test_helper"
require_relative "../../lib/type-profiler"

module TypeProfiler
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

  class SmokeTest < Test::Unit::TestCase
    class Smoke
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

    Dir.glob(File.join(__dir__, "../../smoke/*.rb")).sort.each do |path|
      name = "smoke/" + File.basename(path) 
      code, expected = File.read(path).split("__END__\n")
      test name do
        actual = Smoke.new(name, code).run

        if ENV["TP_UPDATE_SMOKE_RESULTS"] == "1" && expected != actual
          puts "Update \"#{ name }\" !"
          File.write(path, code + "__END__\n" + actual)
          expected = actual
        end

        assert_equal(expected, actual)
      end
    end
  end
end
