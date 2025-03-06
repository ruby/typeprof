require_relative "helper"

module TypeProf
  class DiagnosticTest < Test::Unit::TestCase
    class DummyNode
      def code_range
        nil
      end
    end

    def test_diagnostic
      diag = Diagnostic.new(DummyNode.new, :code_range, "test message")
      assert_nil diag.tags
    end
  end
end
