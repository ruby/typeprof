require_relative '../../helper'

module TypeProf
  class Diagnostic
    module DisableDirective
      class ScannerTest < Test::Unit::TestCase
        def test_when_no_directives
          src = <<~RUBY
            def foo
              x = 1
              y = 2
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_empty ranges
        end

        def test_when_only_inline_enable_comment
          src = <<~RUBY
            def foo
              x = 1 # typeprof:enable
              y = 2
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 0, ranges.size
        end

        def test_when_only_inline_disable_comment
          src = <<~RUBY
            def foo
              x = 1 # typeprof:disable
              y = 2
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 1, ranges.size
          assert_equal (2..2), ranges[0]
        end

        def test_when_only_block_disable_comment
          src = <<~RUBY
            def foo
              # typeprof:disable
              x = 1
              y = 2
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 1, ranges.size
          assert_equal (3..Float::INFINITY), ranges[0]
        end

        def test_when_only_block_disable_and_enable_comment
          src = <<~RUBY
            def foo
              # typeprof:disable
              x = 1
              y = 2
              # typeprof:enable
              z = 3
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 1, ranges.size
          assert_equal (3..4), ranges.first
        end

        def test_when_inline_disable_comment
          src = <<~RUBY
            def foo
              x = 1 # typeprof:disable
              y = 2
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 1, ranges.size
          assert_equal (2..2), ranges[0]
        end

        def test_when_only_block_disable_and_inline_enable_comment
          src = <<~RUBY
            def foo
              # typeprof:disable
              x = 1
              y = 2
              z = 3 # typeprof:enable
              w = 4
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 2, ranges.size
          assert_equal (3..4), ranges[0]
          assert_equal (6..Float::INFINITY), ranges[1]
        end

        def test_when_multiple_comments
          src = <<~RUBY
            def foo
              # typeprof:disable
              x = 1
              # typeprof:enable
              y = 2
              z = 3 # typeprof:disable
              w = 4
            end
          RUBY
          prism_result = Prism.parse(src)
          ranges = Scanner.collect(prism_result, src)

          assert_equal 2, ranges.size
          assert_equal (3..3), ranges[0]
          assert_equal (6..6), ranges[1]
        end
      end
    end
  end
end
