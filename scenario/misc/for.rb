## update
def foo
  for i in 1..100
    return 1
  end
end

def bar
  for i in 1..100
    return 1
  end
end

## assert
class Object
  def foo: -> Integer?
  def bar: -> Integer?
end
