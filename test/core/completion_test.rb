require_relative "../helper"

module TypeProf::Core
  class CompletionTest < Test::Unit::TestCase
    def test_dot_completion
      serv = Service.new

      serv.update_file("test.rb", <<-END)
class Foo
  def foo(n)
    1
  end
  def bar(n)
    "str"
  end
end

def test(x)
  x
end

Foo.new.foo(1.0)
test(Foo.new)
      END

      comps = []
      serv.completion("test.rb", ".", TypeProf::CodePosition.new(11, 2)) do |mid, hint|
        comps << [mid, hint]
      end
      assert_equal([:foo, "Foo#foo : (Float) -> Integer"], comps[0])
      assert_equal([:bar, "Foo#bar : (untyped) -> String"], comps[1])
    end
  end
end