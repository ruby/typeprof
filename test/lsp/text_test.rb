require_relative "../helper"

module TypeProf::LSP
  class TextTest < Test::Unit::TestCase
    def r(row1, col1, row2, col2)
      {
        start: { line: row1, character: col1 },
        end: { line: row2, character: col2 },
      }
    end

    def test_text
      text = Text.new("test.rb", "foo", 0)
      assert_equal("foo", text.text)
    end

    def test_apply_changes1
      text = Text.new("test.rb", "abcde", 0)
      text.apply_changes([{ range: r(0, 1, 0, 4), text: "FOO" }], 0)
      assert_equal("aFOOe", text.text)
      text.apply_changes([{ range: r(0, 1, 0, 4), text: "" }], 0)
      assert_equal("ae", text.text)
    end

    def test_apply_changes2
      text = Text.new("test.rb", "abcde", 0)
      text.apply_changes([
        { range: r(0, 1, 0, 2), text: "" },
        { range: r(0, 1, 0, 2), text: "FOO" },
        { range: r(0, 1, 0, 2), text: "" },
      ], 0)
      assert_equal("aOOde", text.text)
    end

    def test_apply_changes3
      text = Text.new("test.rb", "abc\ndef\nghi", 0)
      text.apply_changes([{ range: r(0, 1, 1, 2), text: "FOO" }], 0)
      assert_equal("aFOOf\nghi", text.text)
      text.apply_changes([{ range: r(0, 1, 1, 2), text: "AAA\nBBB\nCCC" }], 0)
      assert_equal("aAAA\nBBB\nCCCi", text.text)
    end
  end
end
