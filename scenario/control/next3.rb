## update
def foo
  yield 42
end

foo do |n|
  next 1, 2
  "str"
end

## assert
class Object
  def foo: { (Integer) -> (String | [Integer, Integer]) } -> (String | [Integer, Integer])
end
