## update
def foo(&b)
  b.call(1)
end

foo do
  it
end

## assert
class Object
  def foo: { (Integer) -> Integer } -> Integer
end
