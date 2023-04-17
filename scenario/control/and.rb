## update
def foo(x, y)
x && y
end

foo(1, "s")

## assert
class Object
  def foo: (Integer, String) -> (Integer | String)
end