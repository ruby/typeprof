require_relative "../helper"

module TypeProf::LSP
  class ConstantCatalogTest < Test::Unit::TestCase
    def setup
      @catalog = ConstantCatalog.new
    end

    def test_top_level_match_finds_csv
      hits = []
      @catalog.each_match([], "CS") { |name, req| hits << [name, req] }
      csv_hit = hits.find { |name, _| name == :CSV }
      assert_not_nil(csv_hit, "CSV should be discoverable from stdlib catalog")
      assert_equal("csv", csv_hit[1])
    end

    def test_top_level_match_excludes_non_matches
      hits = []
      @catalog.each_match([], "CS") { |name, _req| hits << name }
      assert(hits.all? { |n| n.to_s.start_with?("CS") }, "all results should match prefix")
    end

    def test_scoped_match_finds_net_http
      hits = []
      @catalog.each_match([:Net], "HTTP") { |name, req| hits << [name, req] }
      http_hit = hits.find { |name, _| name == :HTTP }
      assert_not_nil(http_hit, "Net::HTTP should be discoverable")
      assert_equal("net/http", http_hit[1])
    end

    def test_require_name_for_top_level
      assert_equal("csv", @catalog.require_name_for([:CSV]))
    end

    def test_require_name_for_unknown
      assert_nil(@catalog.require_name_for([:NonexistentXyz]))
    end

    def test_dirname_dash_becomes_slash
      assert_equal("bigdecimal/math", @catalog.require_name_for([:BigMath]))
    end

    def test_json_uses_top_level_require_not_subpath
      # Regression: the rdoc-file header in stdlib/json/0/json.rbs points to
      # ext/json/lib/json/common.rb, but the actual require name is just 'json'.
      assert_equal("json", @catalog.require_name_for([:JSON]))
    end

    def test_open_uri_keeps_dash
      # `resolve_require_name` priority: dirname as-is wins when it resolves
      # via Gem.find_files. open-uri's lib file is `lib/open-uri.rb`, so the
      # dash form should win over `open/uri` (which doesn't resolve).
      omit "open-uri not installed in test environment" unless Gem.find_files("open-uri").any?
      assert_equal("open-uri", @catalog.require_name_for([:OpenURI]))
    end
  end
end
