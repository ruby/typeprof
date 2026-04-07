## update
def foo(...)
  extra = "x"
  bar(extra, ...)
end

def bar(a, *b, **c)
  [a, b, c]
end

foo(2, x: 4, y: 5)

## assert
class Object
  def foo: (*Integer, **Integer) -> [String, Array[Integer], { x: Integer, y: Integer }]
  def bar: (String, *Integer, **Integer) -> [String, Array[Integer], { x: Integer, y: Integer }]
end
