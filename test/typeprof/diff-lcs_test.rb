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

        assert(actual =~ /^module Diff\n  module LCS\n(?:(?:    .*?\n|\n)*)^  end\n^end\n/)
        assert_include($&, "def self.diff: (Array[T] | LCS seq1, Array[T] seq2, ?nil callbacks) ?{ (Array[Change] | Change | ContextChange) -> nil } -> (Array[(Array[Change?] | Change | ContextChange)?])")

        assert(actual =~ /^    class Change\n(?:(?:      .*?\n|\n)*)^    end\n/)
        assert_equal(<<-END, $&)
    class Change
      IntClass: untyped
      VALID_ACTIONS: [String, String, String, String, String, String]
      include Comparable

      def self.valid_action?: (String action) -> bool
      attr_reader action: String
      attr_reader position: Integer
      attr_reader element: (Array[T] | T)?
      def initialize: (String action, Integer position, (Array[T] | T)? element) -> void
      def inspect: (*untyped _args) -> String
      def to_a: -> ([String, Integer, (Array[T] | T)?])
      alias to_ary to_a
      def self.from_a: ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]] arr) -> (Change | ContextChange)
      def ==: (untyped other) -> bool
      def <=>: (untyped other) -> Integer?
      def adding?: -> bool
      def deleting?: -> bool
      def unchanged?: -> bool
      def changed?: -> bool
      def finished_a?: -> bool
      def finished_b?: -> bool
    end
        END

        assert(actual =~ /^    class ContextChange.*\n(?:(?:      .*?\n|\n)*)^    end\n/)
        assert_equal(<<-END, $&)
    class ContextChange < Change
      attr_reader old_position: Integer
      attr_reader new_position: Integer
      attr_reader old_element: (Array[T] | T)?
      attr_reader new_element: (Array[T] | T)?
      def initialize: (String action, Integer old_position, (Array[T] | T)? old_element, Integer new_position, (Array[T] | T)? new_element) -> void
      def to_a: -> ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]])
      alias to_ary to_a
      def self.from_a: ([String, [Integer, (Array[T] | T)?], [Integer, (Array[T] | T)?]] arr) -> (Change | ContextChange)
      def self.simplify: (ContextChange event) -> (Change | ContextChange)
      def ==: (untyped other) -> bool
      def <=>: (untyped other) -> Integer?
    end
        END

      ensure
        $LOAD_PATH.replace(load_path_back)
      end
    end
  end
end
