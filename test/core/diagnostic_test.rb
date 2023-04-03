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

    def test_reuse
      serv = Service.new
      serv.update_file("test0.rb", <<-END)
def foo
  unknown
end
      END

      diags = []
      serv.diagnostics("test0.rb") {|diag| diags << diag }
      assert_equal(1, diags.size)

      diag = diags.first
      assert_equal(TypeProf::CodeRange[2, 2, 2, 9], diag.code_range)
      assert_equal("undefined method: Object#unknown", diag.msg)

      serv.update_file("test0.rb", <<-END)
def foo
  # line added
  unknown
end
      END

      diags = []
      serv.diagnostics("test0.rb") {|diag| diags << diag }
      assert_equal(1, diags.size)

      diag = diags.first
      assert_equal(TypeProf::CodeRange[3, 2, 3, 9], diag.code_range)
      assert_equal("undefined method: Object#unknown", diag.msg)
    end
  end
end
