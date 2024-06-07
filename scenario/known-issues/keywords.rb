## update
def foo(a)
  a
end

foo(x: 1)

## assert
class Object
  def foo: (Hash[:x, Integer]) -> Hash[:x, Integer]
end
