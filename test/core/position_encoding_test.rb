require_relative "../helper"

module TypeProf::Core
  class PositionEncodingTest < Test::Unit::TestCase
    def first_node_code_range(service, path)
      nodes = service.instance_variable_get(:@rb_text_nodes)[path]
      nodes.body.stmts.first.code_range
    end

    def test_default_is_utf16
      service = TypeProf::Core::Service.new({})
      # 𐐀 (U+10400) is a non-BMP char: 4 bytes UTF-8, 2 code units UTF-16LE
      service.update_rb_file("t.rb", "𐐀x = 1\n")
      cr = first_node_code_range(service, "t.rb")
      # "𐐀x = 1" ends at UTF-16 code-unit column 7 (2+1+1+1+1+1)
      assert_equal(7, cr.last.column)
    end

    def test_utf8_gives_byte_columns
      service = TypeProf::Core::Service.new(position_encoding: Encoding::UTF_8)
      service.update_rb_file("t.rb", "𐐀x = 1\n")
      cr = first_node_code_range(service, "t.rb")
      # "𐐀x = 1" ends at UTF-8 byte column 9 (4+1+1+1+1+1)
      assert_equal(9, cr.last.column)
    end

    def test_utf32_gives_code_point_columns
      service = TypeProf::Core::Service.new(position_encoding: Encoding::UTF_32LE)
      service.update_rb_file("t.rb", "𐐀x = 1\n")
      cr = first_node_code_range(service, "t.rb")
      # "𐐀x = 1" ends at UTF-32 code-unit (= code point) column 6
      assert_equal(6, cr.last.column)
    end
  end
end
