## update
def bar(x)
end

def foo(x, y)
  bar()
end

foo(1, 2)

## assert
class Object
  def bar: (untyped) -> nil
  def foo: (Integer, Integer) -> untyped
end

## update
def foo(x)
end

foo(1, 2)
self.foo(1, 2)

## diagnostics
(4,0)-(4,3): wrong number of arguments (2 for 1)
(5,5)-(5,8): wrong number of arguments (2 for 1)