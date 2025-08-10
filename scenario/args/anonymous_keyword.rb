## update
def foo(**)
  bar(**)
end

def bar(**)
  nil
end

bar(x: 1, y: "foo")

## assert
class Object
  def foo: (**untyped) -> nil
  def bar: (**Integer | String | untyped) -> nil
end
