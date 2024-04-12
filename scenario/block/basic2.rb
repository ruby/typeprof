## update
def bar(n)
  yield 1.0
end

bar(12) do |n|
  "str"
end

## assert
class Object
  def bar: (Integer) { (Float) -> String } -> String
end
