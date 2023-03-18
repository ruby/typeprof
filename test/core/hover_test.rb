require "test/unit"
require_relative "../../lib/typeprof"

module TypeProf::Core
  class HoverTest < Test::Unit::TestCase
    def test_parameter
      serv = Service.new
      serv.update_file("test0.rb", <<-END)
def foo(variable)
  variable + 1
end

def main(_)
  foo(2)
end
      END

      assert_equal("Integer", serv.hover("test0.rb", TypeProf::CodePosition.new(1, 10)))
      assert_equal("Integer", serv.hover("test0.rb", TypeProf::CodePosition.new(2, 3)))
    end

    def test_block
      serv = Service.new
      serv.update_file("test.rb", <<-END)
def foo(nnn)
  nnn.times do |var|
    var
  end
end

foo(42)
      END

      assert_equal("Integer", serv.hover("test.rb", TypeProf::CodePosition.new(3, 4)))
    end

    def test_gotodefs
      serv = Service.new
      serv.update_file("test0.rb", <<-END)
def foo(variable)
  variable + 1
end

def main(_)
  foo(2)
end
      END

      cr = TypeProf::CodeRange.new(
        TypeProf::CodePosition.new(1, 0),
        TypeProf::CodePosition.new(3, 3),
      )
      assert_equal([cr], serv.gotodefs("test0.rb", TypeProf::CodePosition.new(6, 3)))
    end
  end
end
