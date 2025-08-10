## update
def foo(*)
  bar(*)
end

def bar(*)
  nil
end

bar(1, "foo")

## assert
class Object
  def foo: (*untyped) -> nil
  def bar: (*Integer | String) -> nil
end
