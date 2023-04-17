## update
def foo(n, &b)
  b.call(1.0)
end

foo(12) do |n|
  "str"
end

## assert
class Object
  def foo: (Integer) { (Float) -> String } -> String
end