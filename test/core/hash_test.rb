require_relative "../helper"

module TypeProf::Core
  class ArrayTest < Test::Unit::TestCase
    def test_hash
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo
  {
    a: 1,
    b: "str",
  }
end

def bar
  foo[:a]
end

def baz
  foo[:c] = 1.0
  foo[:c]
end
      END

      assert_equal(
        ["def foo: () -> Hash[:a | :b, Float | Integer | String]"],
        serv.get_method_sig([], false, :foo),
      )
      assert_equal(
        ["def bar: () -> Integer"],
        serv.get_method_sig([], false, :bar),
      )
      assert_equal(
        ["def baz: () -> (Float | Integer | String)"],
        serv.get_method_sig([], false, :baz),
      )
    end
  end
end