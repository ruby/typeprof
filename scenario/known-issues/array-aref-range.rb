## update
def foo
  [1, 2, 3][1..]
end

def bar(a)
  a[0..1]
end

bar([1, "str"])

## assert
class Object
  def foo: -> Array[Integer]?
  def bar: ([Integer, String]) -> Array[Integer | String]?
end
