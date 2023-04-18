## update
class Foo
  def foo(n)
    1
  end

  def bar(n)
    "str"
  end

  #: (Integer) -> Integer
  def baz(n)
    1
  end
end

def test(x)
  x
end

Foo.new.foo(1.0)
test(Foo.new)

## code_lens
(2,2): (Float) -> Integer
(6,2): (untyped) -> String
(16,0): (Foo) -> Foo