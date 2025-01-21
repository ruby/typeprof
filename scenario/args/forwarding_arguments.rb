## update
def foo(...)
  nil
end

## assert
class Object
  def foo: (*untyped, **untyped) -> nil
end

## update
def foo(a, ...)
  a
end

foo(1)

## assert
class Object
  def foo: (Integer, *untyped, **untyped) -> Integer
end
