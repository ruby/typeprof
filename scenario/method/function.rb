## update
def foo(n)
  n
end

class Foo
  def bar
    foo(1)
  end
end

## assert
class Object
  def foo: (Integer) -> Integer
end
class Foo
  def bar: -> Integer
end