## update
def foo
  { **bar, b: 1 }
end

def bar
  { a: 1 }
end

## assert
class Object
  def foo: -> Hash[:a | :b, Integer]
  def bar: -> Hash[:a, Integer]
end
