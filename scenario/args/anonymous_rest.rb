## update
def foo(*)
  bar(*)
end

def bar(*)
  nil
end

def foo_in_if(*)
  if true
    bar(*)
  end
end

bar(1, "foo")

## assert
class Object
  def foo: (*untyped) -> nil
  def bar: (*Integer | String) -> nil
  def foo_in_if: (*untyped) -> nil
end
