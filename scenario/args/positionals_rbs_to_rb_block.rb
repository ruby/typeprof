## update
def foo(&b)
  1.times(&b)
end

# TODO: Object means "void"

## assert
class Object
  def foo: { (Integer) -> Object } -> Integer
end
