## update
def foo
  yield 42
end

foo do |n|
  next 1
  "str"
end

## assert
class Object
  def foo: { (Integer) -> (Integer | String) } -> (Integer | String)
end