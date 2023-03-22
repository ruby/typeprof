require_relative "../helper"

module TypeProf::Core
  class ArrayTest < Test::Unit::TestCase
    def test_array1
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
  def foo(a)
  a
  end
      END

      serv.update_file("test1.rb", <<-END)
  foo([1, 2, 3].to_a)
      END

      assert_equal(
        ["def foo: (Array[Integer]) -> Array[Integer]"],
        serv.get_method_sig([], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)
  foo([1, 2, 3].to_a)
  foo(["str"].to_a)
      END

      assert_equal(
        ["def foo: (Array[Integer] | Array[String]) -> Array[Integer] | Array[String]"],
        serv.get_method_sig([], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)
  foo(["str"].to_a)
      END

      assert_equal(
        ["def foo: (Array[String]) -> Array[String]"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_array2
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def bar(a)
  [a].to_a
end
      END

      serv.update_file("test1.rb", <<-END)
bar(1)
      END

      assert_equal(
        ["def bar: (Integer) -> Array[Integer]"],
        serv.get_method_sig([], false, :bar),
      )

      serv.update_file("test1.rb", <<-END)
bar(1)
bar("str")
      END

      assert_equal(
        ["def bar: (Integer | String) -> Array[Integer | String]"],
        serv.get_method_sig([], false, :bar),
      )

      serv.update_file("test1.rb", <<-END)
bar("str")
      END

      assert_equal(
        ["def bar: (String) -> Array[String]"],
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_aref
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo
  ary = [1, "str"]
  ary[0]
end

def bar
  ary = [1, "str"]
  i = 0
  ary[i]
end
            END

      assert_equal(
        ["def foo: () -> Integer"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: () -> Integer | String"],
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_aset
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo
  ary = [1, "str"]
  ary[0] = 1.0
  ary[0]
end
            END

      assert_equal(
        ["def foo: () -> Float | Integer"],
        serv.get_method_sig([], false, :foo),
      )
    end
  end
end