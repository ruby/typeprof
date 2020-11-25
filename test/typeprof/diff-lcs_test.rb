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

        actual = TestRun.run(name, show_errors: false, show_untyped: false)

        # No special reason to choose these two classes (Goodcheck::Analyzer and Trigger)

        assert(actual =~ /^module Diff\n  module LCS\n(?:(?:    .*?\n|\n)*)^  end\n^end\n/)
        assert_include($&, "def self.diff : (Array[T] | LCS, Array[T], ?nil) ?{ (Array[Change] | Change | ContextChange) -> nil } -> (Array[(Array[Change?] | Change | ContextChange)?])")

        assert(actual =~ /^    class Change\n(?:(?:      .*?\n|\n)*)^    end\n/)
        assert_equal(<<-END, $&)
    class Change
      IntClass : untyped
      VALID_ACTIONS : [String, String, String, String, String, String]
      include Comparable
      attr_reader action : String
      attr_reader position : Integer
      attr_reader element : (Array[T] | T)?
      def self.valid_action? : (String) -> bool
      def initialize : (String, Integer, (Array[T] | T)?) -> nil
      def inspect : (*untyped) -> String
      def to_a : -> ([String, Integer, (Array[T] | T)?])
      def self.from_a : ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]]) -> (Change | ContextChange)
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

        assert(actual =~ /^    class ContextChange.*\n(?:(?:      .*?\n|\n)*)^    end\n/)
        assert_equal(<<-END, $&)
    class ContextChange < Change
      @action : String
      attr_reader old_position : Integer
      attr_reader new_position : Integer
      attr_reader old_element : (Array[T] | T)?
      attr_reader new_element : (Array[T] | T)?
      def initialize : (String, Integer, (Array[T] | T)?, Integer, (Array[T] | T)?) -> nil
      def to_a : -> ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]])
      def self.from_a : ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]]) -> (Change | ContextChange)
      def self.simplify : (ContextChange) -> (Change | ContextChange)
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
