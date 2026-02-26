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
# ^[A]
end

def test2
  test1(Foo.new)
#              ^[B]
end

Foo.new.foo(1.0)
test(Foo.new)

## completion: [A]
Foo#foo : (Float) -> Integer
Foo#bar : (untyped) -> String
Foo#baz : (Foo) -> Foo

## completion: [B]
Foo#foo : (Float) -> Integer
Foo#bar : (untyped) -> String
Foo#baz : (Foo) -> Foo
