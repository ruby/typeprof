## update
def foo(&b)
  b.call(1, '')
end

foo do
  [_1, _2]
end

## assert
class Object
  def foo: { (Integer, String) -> [Integer, String] } -> [Integer, String]
end
