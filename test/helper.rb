if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "test/unit"
require_relative "../lib/typeprof"
