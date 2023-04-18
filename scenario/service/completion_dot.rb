## update
class Foo
  def foo(n)
    1
  end
  def bar(n)
    "str"
  end
end

def test1(x)
  x
end

def test2
  test1(Foo.new)
end

Foo.new.foo(1.0)
test(Foo.new)

## completion
(11, 2)
Foo#foo : (Float) -> Integer
Foo#bar : (untyped) -> String

## completion
(15, 15)
Foo#foo : (Float) -> Integer
Foo#bar : (untyped) -> String