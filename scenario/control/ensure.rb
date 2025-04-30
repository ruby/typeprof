## update
def bar(n)
end

def foo(n)
  n = "str"
  1.0
ensure
  bar(n)
end

foo(1)

## assert
class Object
  def bar: (Integer | String) -> nil
  def foo: (Integer) -> Float
end
