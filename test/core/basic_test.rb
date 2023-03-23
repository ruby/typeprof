require_relative "../helper"

module TypeProf::Core
  class BasicTest < Test::Unit::TestCase
    def test_multi_args
      serv = Service.new

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
      serv = Service.new

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
        ["def bar: -> Integer"],
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_attrasgn
      serv = Service.new

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
        ["def foo: -> Integer"],
        serv.get_method_sig([:C], false, :foo),
      )
    end

    def test_toplevel_function
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(n)
  n
end

class Foo
  def bar
    foo(1)
  end
end
      END

      assert_equal(
        ["def foo: (Integer) -> Integer"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_empty_def
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo(x)
end

foo(1)
      END

      assert_equal(
        ["def foo: (Integer) -> nil"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_rbs_module
      serv = Service.new

      serv.update_file("test.rb", src = <<-END)
def foo
  rand # Kernel#rand
end
      END

      assert_equal(
        ["def foo: -> Float"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_module
      serv = Service.new

      serv.update_file("test.rb", src = <<-END)
module M
  def foo
    42
  end
end

class C
  include M
  def bar
    foo
  end
end
      END

      assert_equal(
        ["def bar: -> Integer"],
        serv.get_method_sig([:C], false, :bar),
      )
    end

    def test_defs
      serv = Service.new

      serv.update_file("test.rb", <<-END)
class Foo
  def self.foo
    1
  end

  def self.bar
    foo
  end
end

def test
  Foo.foo
end
      END

      assert_equal(
        ["def foo: -> Integer"],
        serv.get_method_sig([:Foo], true, :foo),
      )

      assert_equal(
        ["def bar: -> Integer"],
        serv.get_method_sig([:Foo], true, :bar),
      )

      assert_equal(
        ["def test: -> Integer"],
        serv.get_method_sig([], false, :test),
      )
    end

    def test_rbs_alias
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo
  1.0.phase
end
      END

      assert_equal(
        ["def foo: -> (Float | Integer)"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_dstr
      serv = Service.new

      serv.update_file("test.rb", <<-'END')
def foo
  "foo#{ bar(1) }"
  "foo#{ bar(1) }baz#{ qux(1.0) }"
end

def bar(n)
  "bar"
end

def qux(n)
  "qux"
end
      END

      assert_equal(
        ["def foo: -> String"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: (Integer) -> String"],
        serv.get_method_sig([], false, :bar),
      )

      assert_equal(
        ["def qux: (Float) -> String"],
        serv.get_method_sig([], false, :qux),
      )
    end

    def test_op_asgn_or
      serv = Service.new

      serv.update_file("test.rb", <<-'END')
def foo
  $x
end

$x ||= 1
$x ||= "str"
      END

      assert_equal(
        ["def foo: -> (Integer | String)"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_op_asgn1
      serv = Service.new

      serv.update_file("test.rb", <<-'END')
def foo
  ary = [0]
  ary[0] ||= "str"
  ary
end
      END

      assert_equal(
        ["def foo: -> [Integer | String]"],
        serv.get_method_sig([], false, :foo),
      )
    end
  end
end
