require "test/unit"
require_relative "../lib/typeprof"

module TypeProf
  class CodeRangeTest < Test::Unit::TestCase
    def test_position
      p1 = CodePosition.new(1, 1)
      p2 = CodePosition.new(1, 2)
      p3 = CodePosition.new(2, 0)
      p4 = CodePosition.new(2, 0)
      assert_operator(p1, :<, p2)
      assert_operator(p1, :<, p3)
      assert_operator(p3, :==, p4)
    end

    def test_eq
      p0 = CodePosition.new(1, 0)
      p1 = CodePosition.new(1, 1)
      p2 = CodePosition.new(1, 2)

      cr0 = CodeRange.new(p0, p1)
      cr1 = CodeRange.new(p0, p1)
      cr2 = CodeRange.new(p0, p2)

      assert_equal(true, cr0 == cr1)
      assert_equal(false, cr0 == cr2)
    end

    def test_include?
      p0 = CodePosition.new(1, 0)
      p1 = CodePosition.new(1, 1)
      p2 = CodePosition.new(1, 2)
      p3 = CodePosition.new(2, 0)
      p4 = CodePosition.new(2, 1)

      cr = CodeRange.new(p1, p3)
      assert_equal(false, cr.include?(p0))
      assert_equal(true, cr.include?(p2))
      assert_equal(false, cr.include?(p4))
    end
  end
end
