## update
def foo(a)
  a
end

foo(x: 1)

## assert
class Object
  def foo: ({ x: Integer }) -> { x: Integer }
end
