# frozen_string_literal: true

require "bundler/inline"

gemfile(true) do
  source "https://rubygems.org"

  gem "typeprof"
  # If you want to test against edge TypeProf replace the previous line with this:
  # gem "typeprof", github: "ruby/typeprof", branch: "master"

  gem "test-unit"
end

require "test/unit"
require "typeprof"

def infer(source)
  service = TypeProf::Core::Service.new({})
  service.update_rb_file("(typeprof)", source)
  service.dump_declarations("(typeprof)")
end

class BugTest < Test::Unit::TestCase
  def test_example
    source = <<~RUBY
      def foo(n)
        p n
        n.to_s
      end

      p foo(42)
    RUBY

    expected = <<~RBS
      class Object
        def foo: (Integer) -> String
      end
    RBS

    assert_equal(expected, infer(source))
  end
end
