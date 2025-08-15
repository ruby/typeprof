## update
def foo(&b)
  1.times(&b)
end

## assert
class Object
  def foo: { (Integer) -> untyped } -> Integer
end
