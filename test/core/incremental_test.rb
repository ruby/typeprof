require_relative "../helper"

module TypeProf::Core
  class IncrementalTest < Test::Unit::TestCase
    def test_incremental1
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(x)
  x * x
end
      END

      assert_equal(
        ["def foo: (untyped) -> untyped"],
        serv.get_method_sig([], false, :foo),
      )

      #serv.show_graph([:Object], :foo)

      serv.update_file("test1.rb", <<-END)


def main(_)
  foo(1)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        serv.get_method_sig([], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)


def main(_)
  foo("str")
end
      END

      assert_equal(
        ["def foo: (String) -> untyped"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_incremental2
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo(x)
  x + 1
end

def main(_)
  foo(2)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        serv.get_method_sig([], false, :foo),
      )

      serv.update_file("test.rb", <<-END)

def foo(x)
  x + 1.0
end

def main(_)
  foo(2)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Float"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_incremental3
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo(x)
  x + 1
end

def main(_)
  foo(2)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        serv.get_method_sig([], false, :foo),
      )

      #serv.dump_graph("test.rb")

      serv.update_file("test.rb", <<-END)

def foo(x)
  x + 1
end

def main(_)
  foo("str")
end
      END

      assert_equal(
        ["def foo: (String) -> untyped"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_incremental4
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
class C
  def foo(n)
    C
  end
end
      END

      #serv.dump_graph("test0.rb")

      assert_equal(
        ["def foo: (untyped) -> singleton(C)"],
        serv.get_method_sig([:C], false, :foo),
      )

      serv.update_file("test0.rb", <<-END)
class C
  class C
  end

  def foo(n)
    C
  end
end
      END
      #serv.dump_graph("test0.rb")

      assert_equal(
        ["def foo: (untyped) -> singleton(C::C)"],
        serv.get_method_sig([:C], false, :foo),
      )

      serv.update_file("test0.rb", <<-END)
class C
  class D
  end

  def foo(n)
    C
  end
end
      END

      #serv.dump_graph("test0.rb")

      assert_equal(
        ["def foo: (untyped) -> singleton(C)"],
        serv.get_method_sig([:C], false, :foo),
      )
    end

    def test_incremental5
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(n, &b)
  b.call(1.0)
end
      END

      serv.update_file("test1.rb", <<-END)
def bar(_)
  foo(12) do |n|
    "str"
  end
end

def baz(_)
  foo(12) do |n|
    "str"
  end
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) { (Float) -> String } | { (Float) -> String } -> String"],
        serv.get_method_sig([], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)
def bar(_)
  foo(12) do |n|
    1
  end
end

def baz(_)
  foo(12) do |n|
    "str"
  end
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) { (Float) -> Integer } | { (Float) -> String } -> (Integer | String)"],
        serv.get_method_sig([], false, :foo),
      )

      serv.update_file("test1.rb", <<-END)
def bar(_)
  foo(12) do |n|
    1
  end
end

def baz(_)
  foo(12) do |n|
    1
  end
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) { (Float) -> Integer } | { (Float) -> Integer } -> Integer"],
        serv.get_method_sig([], false, :foo),
      )
    end
  end
end