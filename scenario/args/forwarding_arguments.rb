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

## update
def foo(...)
  bar(...)
end

def bar(*a, **b)
  [a, b]
end

foo(1, x: 4, y: 5)

## assert
class Object
  def foo: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
  def bar: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
end
