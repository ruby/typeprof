## update
def bar(n)
end

def foo(n)
  n = "str"
  1.0
ensure
  ## TODO: bar should accept "Integer | String" ???
  bar(n)
end

foo(1)

## assert
class Object
  def bar: (String) -> nil
  def foo: (Integer) -> Float?
end
