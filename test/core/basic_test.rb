require_relative "../helper"

module TypeProf::Core
  class BasicTest < Test::Unit::TestCase
    def test_class1
      serv = Service.new

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
      serv = Service.new

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
      serv = Service.new

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
      serv = Service.new

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
      serv = Service.new

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

      serv.update_file("test1.rb", <<-END)
def bar(n)
  yield 1.0
end

bar(12) do |n|
  "str"
end
      END

      #serv.dump_graph("test0.rb")
      assert_equal(
        ["def bar: (Integer) ({ (Float) -> String }) -> String"],
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_block2
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo
  1.times {|_| }
end

def bar
  1.times
end
      END

      assert_equal(
        ["def foo: () -> Integer"],
        serv.get_method_sig([], false, :foo),
      )
      assert_equal(
        ["def bar: () -> Enumerator"], # TODO: type parameter
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_branch
      serv = Service.new

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
      serv = Service.new

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
        ["def bar: () -> Integer"],
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
        ["def foo: () -> Integer"],
        serv.get_method_sig([:C], false, :foo),
      )
    end

    def test_and
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(x, y)
  x and y
end

foo(1, "s")
      END

      assert_equal(
        ["def foo: (Integer, String) -> Integer | String"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_dvar
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(&blk)
  blk.call(42)
end

def bar
  a = "str"
  foo do |x|
    a = x
    a
  end
  a
end
      END

      assert_equal(
        ["def foo: () ({ (Integer) -> Integer | String }) -> Integer | String"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_dvar2
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(x)
  x = "str"
  1.times do |_|
    x = 42
  end
  x
end

def bar(x)
  x = "str"
  1.times do |x|
    x = 42
  end
  x
end
      END

      assert_equal(
        ["def foo: (Integer | String) -> Integer | String"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: (String) -> String"],
        serv.get_method_sig([], false, :bar),
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

    def test_return
      serv = Service.new

      serv.update_file("test0.rb", <<-END)
def foo(x)
  return if x
  "str"
end

def bar(x)
  return 1 if x
  "str"
end

def baz(x)
  1.times do |_|
    return 1
  end
  "str"
end
      END

      assert_equal(
        ["def foo: (untyped) -> NilClass | String"],
        serv.get_method_sig([], false, :foo),
      )
      assert_equal(
        ["def bar: (untyped) -> Integer | String"],
        serv.get_method_sig([], false, :bar),
      )
      assert_equal(
        ["def baz: (untyped) -> Integer | String"],
        serv.get_method_sig([], false, :baz),
      )
    end

    def test_pedantic_lvar
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo
  x = x + 1
end
      END

      assert_equal(
        ["def foo: () -> untyped"],
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
        ["def foo: (Integer) -> NilClass"],
        serv.get_method_sig([], false, :foo),
      )
    end

    def test_initialize
      serv = Service.new

      serv.update_file("test.rb", src = <<-END)
class A
end

class B
  def initialize(xxx)
    @xxx = xxx
  end
end

class C
end

def foo
  B.new(1)
end
      END

      assert_equal("Integer", serv.hover("test.rb", TypeProf::CodePosition.new(5, 19)))

      serv.update_file("test.rb", src)

      assert_equal("Integer", serv.hover("test.rb", TypeProf::CodePosition.new(5, 19)))
    end

    def test_rbs_module
      serv = Service.new

      serv.update_file("test.rb", src = <<-END)
def foo
  rand # Kernel#rand
end
      END

      assert_equal(
        ["def foo: () -> Float"],
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
        ["def bar: () -> Integer"],
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
        ["def foo: () -> Integer"],
        serv.get_method_sig([:Foo], true, :foo),
      )

      assert_equal(
        ["def bar: () -> Integer"],
        serv.get_method_sig([:Foo], true, :bar),
      )

      assert_equal(
        ["def test: () -> Integer"],
        serv.get_method_sig([], false, :test),
      )
    end

    def test_masgn_for_lasgn
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def baz
  [1, 1.0, "str"]
end

def foo
  x, y, z, w = baz
  x
end

def bar
  x = nil
  1.times do |_|
    x, y, z, w = baz
  end
  x
end
      END

      assert_equal(
        ["def foo: () -> Integer"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: () -> Integer | NilClass"],
        serv.get_method_sig([], false, :bar),
      )
    end

    def test_gvar
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo
  $foo = "str"
end

def bar
  $foo
end

def baz
  $VERBOSE
end
      END

      assert_equal(
        ["def foo: () -> String"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: () -> String"],
        serv.get_method_sig([], false, :bar),
      )

      assert_equal(
        ["def baz: () -> FalseClass | NilClass | TrueClass"],
        serv.get_method_sig([], false, :baz),
      )
    end

    def test_case
      serv = Service.new

      serv.update_file("test.rb", <<-END)
def foo(n)
  case n
  when 1
    1
  when 2
    "str"
  else
    1.0
  end
end

def bar(n)
  case n
  when 1
    1
  when 2
    "str"
  end
end

def baz(n)
  case n
  when 1
    1
  when 2
    "str"
  else
    raise
  end
end
      END

      assert_equal(
        ["def foo: (untyped) -> Float | Integer | String"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: (untyped) -> Integer | NilClass | String"],
        serv.get_method_sig([], false, :bar),
      )

      assert_equal(
        ["def baz: (untyped) -> Integer | String"],
        serv.get_method_sig([], false, :baz),
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
        ["def foo: () -> Float | Integer"],
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
        ["def foo: () -> String"],
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

    def test_loop
      serv = Service.new

      serv.update_file("test.rb", <<-'END')
def foo
  a = [[nil]]
  while a
    a = a[0]
  end
  a
end

def bar
  a = [[nil]]
  until a
    a = a[0]
  end
  a
end

def baz
  a = [[nil]]
  begin a
    a = a[0]
  end while a
  a
end
      END

      assert_equal(
        ["def foo: () -> NilClass | [NilClass] | [[NilClass]]"],
        serv.get_method_sig([], false, :foo),
      )

      assert_equal(
        ["def bar: () -> NilClass | [NilClass] | [[NilClass]]"],
        serv.get_method_sig([], false, :bar),
      )

      assert_equal(
        ["def baz: () -> NilClass | [NilClass] | [[NilClass]]"],
        serv.get_method_sig([], false, :baz),
      )
    end
  end
end
