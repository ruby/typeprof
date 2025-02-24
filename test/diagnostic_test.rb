require_relative "helper"

module TypeProf
  class DiagnosticTest < Test::Unit::TestCase
    class DummyNode
      def code_range
        nil
      end
    end

    def test_diagnostic_with_default_values
      diag = Diagnostic.new(DummyNode.new, :code_range, "test message")
      assert_equal :error, diag.severity
      assert_nil diag.tags
    end

    def test_diagnostic_with_custom_severity
      diag = Diagnostic.new(DummyNode.new, :code_range, "test message", severity: :warning)
      assert_equal :warning, diag.severity
    end

    def test_diagnostic_with_custom_tags
      diag = Diagnostic.new(DummyNode.new, :code_range, "test message", tags: [:deprecated])
      assert_equal [:deprecated], diag.tags
    end

    def test_diagnostic_with_custom_severity_and_tags
      diag = Diagnostic.new(DummyNode.new, :code_range, "test message", severity: :info, tags: [:experimental])
      assert_equal :info, diag.severity
      assert_equal [:experimental], diag.tags
    end
  end
end
