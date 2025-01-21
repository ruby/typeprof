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
  def foo: (*Integer, **Hash[:x | :y, Integer]) -> [Array[Integer], Hash[:x | :y, Integer]]
  def bar: (*Integer, **Hash[:x | :y, Integer]) -> [Array[Integer], Hash[:x | :y, Integer]]
end
