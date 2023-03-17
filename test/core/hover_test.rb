require "test/unit"
require_relative "../../lib/typeprof"

module TypeProf::Core
  class HoverTest < Test::Unit::TestCase
    def test_hover
      serv = Service.new
      serv.update_file("test0.rb", <<-END)
def foo(variable)
  variable + 1
end

def main(_)
  foo(2)
end
      END

      assert_equal("Integer", serv.hover("test0.rb", CodePosition.new(2, 3)))
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

      cr = CodeRange.new(
        CodePosition.new(1, 0),
        CodePosition.new(3, 3),
      )
      assert_equal([cr], serv.gotodefs("test0.rb", CodePosition.new(6, 3)))
    end
  end
end
