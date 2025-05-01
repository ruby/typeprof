## update
def foo(&)
  bar(&)
end

def bar(&b)
  b.call(1.0)
end

foo do |n|
  "str"
end

## assert
class Object
  def foo: -> untyped
  def bar: { (Float) -> untyped } -> untyped
end
