## update
#: (*Integer) -> Integer
def foo(x, y)
  x + y
end

## assert
class Object
  def foo: (Integer, Integer) -> Integer
end

## update
#: (*Integer) -> String
def foo(x, y)
  x + y
end

## diagnostics
(3,2)-(3,7): expected: String; actual: Integer
