require_relative "helper"
require_relative "harness"

module TypeProf::Core
  class SmokeTest < Test::Unit::TestCase
    Dir.glob(File.join(__dir__, "../smoke/**/*.rb")) do |smoke|
      test "#{ File.expand_path(smoke) } " do
        TypeProf::Core.test_harness(smoke, false) do |exp, act|
          assert_equal(exp, act)
        end
      end
    end
  end
end