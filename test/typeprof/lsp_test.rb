require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class LSPTest < Test::Unit::TestCase
    test "analyze local variable definition" do
      _, definition_table = TypeProf::ISeq::compile_str(<<~EOS, "path/to/file")
      message = "Hello"
      puts(message) # `message = "Hello"`

      1.times do |n|
        puts(message) # `message = "Hello"`
      end

      ["Goodbye"].each do |message|
        puts(message) # not `message = "Hello"` but a parameter `|message|`
      end
      def foo(message)
        puts(message)
      end
      EOS
      # same level use
      defs = definition_table[CodeLocation.new(2, 5)].to_a
      assert_equal(defs[0][1].inspect, "(1,0)-(1,17)")
      # nested level use
      defs = definition_table[CodeLocation.new(5, 7)].to_a
      assert_equal(defs[0][1].inspect, "(1,0)-(1,17)")
      # block parameter use
      # FIXME: the range doesn't point the actual param range
      defs = definition_table[CodeLocation.new(9, 7)].to_a
      assert_equal(defs[0][1].inspect, "(8,0)-(8,1)")

      # method parameter use
      defs = definition_table[CodeLocation.new(12, 7)].to_a
      assert_equal(defs[0][1].inspect, "(11,0)-(11,1)")
    end
  end
end