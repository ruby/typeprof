if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start
end

require "test/unit"
require_relative "../lib/typeprof"

class Test::Unit::TestCase
  # Encoding.default_external is US-ASCII when LANG is not set, which must
  # not affect how TypeProf reads files
  def with_default_external(encoding)
    orig = Encoding.default_external
    Encoding.default_external = encoding
    yield
  ensure
    Encoding.default_external = orig
  end
end
