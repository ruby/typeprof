require_relative "../helper"

module TypeProf::Core
  class DiagnosticTest < Test::Unit::TestCase
    def test_nomethoderror
      serv = Service.new
      serv.update_file("test0.rb", <<-END)
foo
      END

      diags = []
      serv.diagnostics("test0.rb") {|diag| diags << diag }
      assert_equal(1, diags.size)

      diag = diags.first
      assert_equal("undefined method: Object#foo", diag.msg)
    end

    def test_wrongnumber
      serv = Service.new
      serv.update_file("test0.rb", <<-END)
def foo(variable)
end

foo(1, 2)
foo()
      END

      diags = []
      serv.diagnostics("test0.rb") {|diag| diags << diag }
      assert_equal(2, diags.size)

      diag = diags[0]
      assert_equal("wrong number of arguments (2 for 1)", diag.msg)

      diag = diags[1]
      assert_equal("wrong number of arguments (0 for 1)", diag.msg)
    end
  end
end
