require_relative "../helper"

module TypeProf::Core
  class IncrementalTest < Test::Unit::TestCase
    def test_incremental1
      core = Service.new

      core.update_rb_file("test0.rb", <<-END)
def foo(x)
  x * x
end
      END

      assert_equal(
        ["def foo: (untyped) -> untyped"],
        core.get_method_sig([], false, :foo),
      )

      #core.show_graph([:Object], :foo)

      core.update_rb_file("test1.rb", <<-END)


def main(_)
  foo(1)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        core.get_method_sig([], false, :foo),
      )

      core.update_rb_file("test1.rb", <<-END)


def main(_)
  foo("str")
end
      END

      assert_equal(
        ["def foo: (String) -> untyped"],
        core.get_method_sig([], false, :foo),
      )
    end

    def test_incremental2
      core = Service.new

      core.update_rb_file("test.rb", <<-END)
def foo(x)
  x + 1
end

def main(_)
  foo(2)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        core.get_method_sig([], false, :foo),
      )

      core.update_rb_file("test.rb", <<-END)

def foo(x)
  x + 1.0
end

def main(_)
  foo(2)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Float"],
        core.get_method_sig([], false, :foo),
      )
    end

    def test_incremental3
      core = Service.new

      core.update_rb_file("test.rb", <<-END)
def foo(x)
  x + 1
end

def main(_)
  foo(2)
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        core.get_method_sig([], false, :foo),
      )

      #core.dump_graph("test.rb")

      core.update_rb_file("test.rb", <<-END)

def foo(x)
  x + 1
end

def main(_)
  foo("str")
end
      END

      assert_equal(
        ["def foo: (String) -> untyped"],
        core.get_method_sig([], false, :foo),
      )
    end

    def test_incremental4
      core = Service.new

      core.update_rb_file("test0.rb", <<-END)
class C
  def foo(n)
    C
  end
end
      END

      #core.dump_graph("test0.rb")

      assert_equal(
        ["def foo: (untyped) -> singleton(C)"],
        core.get_method_sig([:C], false, :foo),
      )

      core.update_rb_file("test0.rb", <<-END)
class C
  class C
  end

  def foo(n)
    C
  end
end
      END
      #core.dump_graph("test0.rb")

      assert_equal(
        ["def foo: (untyped) -> singleton(C::C)"],
        core.get_method_sig([:C], false, :foo),
      )

      core.update_rb_file("test0.rb", <<-END)
class C
  class D
  end

  def foo(n)
    C
  end
end
      END

      #core.dump_graph("test0.rb")

      assert_equal(
        ["def foo: (untyped) -> singleton(C)"],
        core.get_method_sig([:C], false, :foo),
      )
    end

    def test_incremental5
      core = Service.new

      core.update_rb_file("test0.rb", <<-END)
def foo(n, &b)
  b.call(1.0)
end
      END

      core.update_rb_file("test1.rb", <<-END)
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

      #core.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) { (Float) -> String } | { (Float) -> String } -> String"],
        core.get_method_sig([], false, :foo),
      )

      core.update_rb_file("test1.rb", <<-END)
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

      #core.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) { (Float) -> Integer } | { (Float) -> String } -> (Integer | String)"],
        core.get_method_sig([], false, :foo),
      )

      core.update_rb_file("test1.rb", <<-END)
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

      #core.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) { (Float) -> Integer } | { (Float) -> Integer } -> Integer"],
        core.get_method_sig([], false, :foo),
      )
    end
  end
end