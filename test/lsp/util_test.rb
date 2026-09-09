require_relative "../helper"
require "tempfile"

module TypeProf::LSP
  class UtilTest < Test::Unit::TestCase
    def test_load_json_with_comments_reads_non_ascii_as_utf8
      Tempfile.create(["typeprof.conf", ".jsonc"]) do |f|
        f.write("{\n  // 日本語コメント\n  \"typeprof_version\": \"experimental\",\n  \"analysis_unit_dirs\": [\"lib\"],\n}\n")
        f.flush

        conf = with_default_external(Encoding::US_ASCII) do
          TypeProf::LSP.load_json_with_comments(f.path, symbolize_names: true)
        end

        assert_equal({ typeprof_version: "experimental", analysis_unit_dirs: ["lib"] }, conf)
      end
    end
  end
end
