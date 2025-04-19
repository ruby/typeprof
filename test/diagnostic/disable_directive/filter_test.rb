require_relative '../../helper'

module TypeProf
  class Diagnostic
    module DisableDirective
      class FilterTest < Test::Unit::TestCase
        def test_skip_when_line_is_in_range
          ranges = [1..3]
          filter = Filter.new(ranges)

          assert_equal(true, filter.skip?(1))
          assert_equal(true, filter.skip?(2))
          assert_equal(true, filter.skip?(3))
        end

        def test_not_ignore_when_line_is_not_in_range
          ranges = [2..3]
          filter = Filter.new(ranges)

          assert_equal(false, filter.skip?(1))
          assert_equal(false, filter.skip?(4))
        end

        def test_with_empty_ranges
          filter = Filter.new([])

          assert_equal(false, filter.skip?(1))
        end

        def test_with_infinite_range
          ranges = [2..Float::INFINITY]
          filter = Filter.new(ranges)

          assert_equal(false, filter.skip?(1))
          assert_equal(true, filter.skip?(2))
          assert_equal(true, filter.skip?(100))
        end
      end
    end
  end
end
