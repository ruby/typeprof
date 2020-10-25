require_relative "test_helper"
require_relative "../../lib/typeprof"

module TypeProf
  class DiffLCSTest < Test::Unit::TestCase
    test "testbed/diff-lcs" do
      begin
        TestRun.setup_testbed_repository("diff-lcs", "https://github.com/mame/diff-lcs.git", "de838d2df80514adbf22c26daed728ddd06af60b")

        load_path_back = $LOAD_PATH

        $LOAD_PATH << File.join(__dir__, "../../testbed/diff-lcs/lib")

        name = "testbed/diff-lcs-entrypoint.rb"

        actual = TestRun.run(name, show_errors: false, pedantic_output: false)

        # No special reason to choose these two classes (Goodcheck::Analyzer and Trigger)

        assert(actual =~ /^module Diff::LCS\n(?:(?:  .*?\n)*)^end\n/)
        assert_include($&, "def self.diff : (Array[T] | Diff::LCS, Array[T], ?nil) -> (Array[(Array[Diff::LCS::Change?] | Diff::LCS::Change | Diff::LCS::ContextChange)?])")

        assert(actual =~ /^class Diff::LCS::Change\n(?:(?:  .*?\n)*)^end\n/)
        assert_equal(<<~END, $&)
          class Diff::LCS::Change
            include Comparable
            attr_reader action : String
            attr_reader position : Integer
            attr_reader element : (Array[T] | T)?
            def self.valid_action? : (String) -> bool
            def initialize : (String, Integer, (Array[T] | T)?) -> nil
            def inspect : (*untyped) -> String
            def to_a : -> ([String, Integer, (Array[T] | T)?])
            def self.from_a : ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]]) -> (Diff::LCS::Change | Diff::LCS::ContextChange)
            def == : (untyped) -> bool
            def <=> : (untyped) -> Integer?
            def adding? : -> bool
            def deleting? : -> bool
            def unchanged? : -> bool
            def changed? : -> bool
            def finished_a? : -> bool
            def finished_b? : -> bool
          end
        END

        assert(actual =~ /^class Diff::LCS::ContextChange.*\n(?:(?:  .*?\n)*)^end\n/)
        assert_equal(<<~END, $&)
          class Diff::LCS::ContextChange < Diff::LCS::Change
            @action : String
            attr_reader old_position : Integer
            attr_reader new_position : Integer
            attr_reader old_element : (Array[T] | T)?
            attr_reader new_element : (Array[T] | T)?
            def initialize : (String, Integer, (Array[T] | T)?, Integer, (Array[T] | T)?) -> nil
            def to_a : -> ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]])
            def self.from_a : ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]]) -> (Diff::LCS::Change | Diff::LCS::ContextChange)
            def self.simplify : (Diff::LCS::ContextChange) -> (Diff::LCS::Change | Diff::LCS::ContextChange)
            def == : (untyped) -> bool
            def <=> : (untyped) -> Integer?
          end
        END

      ensure
        $LOAD_PATH.replace(load_path_back)
      end
    end
  end
end
