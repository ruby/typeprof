require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class SmokeTest < Test::Unit::TestCase
    Dir.glob(File.join(__dir__, "../../smoke/*.rb")).sort.each do |path|
      rbs = path + "s" if File.readable?(path + "s") # check if .rbs exists
      name = "smoke/" + File.basename(path) 
      code, expected = File.read(path).split("__END__\n")
      if code =~ /\A# RUBY_VERSION >= (\d+)\.(\d+)$/
        major, minor = RUBY_VERSION.split(".")[0, 2].map {|s| s.to_i }
        skip = true unless ([major, minor] <=> [$1.to_i, $2.to_i]) >= 0
      end
      test name do
        actual = TestRun.run(name, rbs_path: rbs)

        if ENV["TP_UPDATE_SMOKE_RESULTS"] == "1" && expected != actual
          puts "Update \"#{ name }\" !"
          File.write(path, code + "__END__\n" + actual)
          expected = actual
        end

        assert_equal(expected, actual)
      end unless skip
    end
  end
end
