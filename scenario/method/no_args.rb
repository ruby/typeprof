## update
def foo
  1
end

def bar
  foo
end

## assert
class Object
  def foo: -> Integer
  def bar: -> Integer
end