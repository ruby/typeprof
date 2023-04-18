## update
class Foo
  def foo(n)
    1
  end
  def bar(n)
    "str"
  end
  #: (Foo) -> Foo
  def baz(_)
    _
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
(15, 2)
Foo#foo : (Float) -> Integer
Foo#bar : (untyped) -> String
Foo#baz : (Foo) -> Foo

## completion
(19, 15)
Foo#foo : (Float) -> Integer
Foo#bar : (untyped) -> String
Foo#baz : (Foo) -> Foo
