require "test/unit"
require_relative "../lib/typeprof"

module TypeProf
  class BasicTest < Test::Unit::TestCase
    def test_class1
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class C
  def initialize(n)
    n
  end

  def foo(n)
    C
  end
end
C.new(1).foo("str")
      END

      assert_equal(
        ["def initialize: (Integer) -> Integer"],
        serv.get_method_sig([:C], false, :initialize),
      )
      assert_equal(
        ["def foo: (String) -> singleton(C)"],
        serv.get_method_sig([:C], false, :foo),
      )
    end

    def test_class2
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class C
  class D
    def foo(n)
      C
    end
  end
end
C::D.new(1).foo("str")
      END

      assert_equal(
        ["def foo: (String) -> singleton(C)"],
        serv.get_method_sig([:C, :D], false, :foo),
      )
    end

    def test_rbs_const
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
def foo(_)
  RUBY_VERSION
end
      END

      assert_equal(
        ["def foo: (untyped) -> String"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_const
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class C
  X = 1
end

class D < C
end

def foo(_)
  D::X
end
      END

      assert_equal(
        ["def foo: (untyped) -> Integer"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_block
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
def foo(n, &b)
  b.call(1.0)
end

foo(12) do |n|
  "str"
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (Integer) ({ (Float) -> String }) -> String"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_branch
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
def foo(n)
  n ? 1 : "str"
end
def bar(n)
  n = 1 if n
  n
end
def baz(n)
  n = 1 unless n
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (untyped) -> Integer | String"],
        serv.get_method_sig([], false, :foo),
      )
      assert_equal(
        ["def bar: (Integer) -> Integer"],
        serv.get_method_sig([], false, :bar),
      )
      assert_equal(
        ["def baz: (Integer) -> Integer | NilClass"],
        serv.get_method_sig([], false, :baz),
      )

      serv.update_file("test0.rb", <<-END)
def foo(n)
  n ? 1 : "str"
end
def bar(n)
  n = 1 if n
  n
end
def baz(n)
  n = 1 unless n
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (untyped) -> Integer | String"],
        serv.get_method_sig([], false, :foo),
      )
      assert_equal(
        ["def bar: (Integer) -> Integer"],
        serv.get_method_sig([], false, :bar),
      )
      assert_equal(
        ["def baz: (Integer) -> Integer | NilClass"],
        serv.get_method_sig([], false, :baz),
      )
    end

    def test_ivar
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class C
  def initialize(x)
    @x = 42
  end

  def foo(_)
    @x
  end
end

class D < C
  def bar(_)
    @x
  end
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: (untyped) -> Integer"],
        serv.get_method_sig([:C], false, :foo),
      )
      assert_equal(
        ["def bar: (untyped) -> Integer"],
        serv.get_method_sig([:D], false, :bar),
      )

      serv.update_file("test0.rb", <<-END)
class C
  def initialize(x)
    @x = "42"
  end

  def foo(_)
    @x
  end
end

class D < C
  def bar(_)
    @x
  end
end
      END

      assert_equal(
        ["def foo: (untyped) -> String"],
        serv.get_method_sig([:C], false, :foo),
      )
      assert_equal(
        ["def bar: (untyped) -> String"],
        serv.get_method_sig([:D], false, :bar),
      )
    end

    def test_multi_args
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class Foo
  def initialize(x, y, z)
    @x = x
    @y = y
    @z = z
  end
end

Foo.new(1, 1.0, "String")
      END

      assert_equal(
        ["def initialize: (Integer, Float, String) -> String"],
        serv.get_method_sig([:Foo], false, :initialize),
      )
    end

    def test_no_args
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
def foo
  1
end

def bar
  foo
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def bar: () -> Integer"],
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_attrasgn
      serv = TypeProf::Service.new

      serv.update_file("test0.rb", <<-END)
class C
  def foo=(x)
    @foo = x
  end

  def foo
    @foo
  end
end

f = C.new
f.foo = 42
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def foo: () -> Integer"],
        serv.get_method_sig([:C], false, :foo),
      )
    end
  end
end
