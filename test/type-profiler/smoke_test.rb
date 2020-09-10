require_relative "test_helper"
require_relative "../../lib/type-profiler"

module TypeProfiler
  class SmokeTest < Test::Unit::TestCase
    Dir.glob(File.join(__dir__, "../../smoke/*.rb")).sort.each do |path|
      name = "smoke/" + File.basename(path) 
      code, expected = File.read(path).split("__END__\n")
      test name do
        actual = TestRun.run(name, code)

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
