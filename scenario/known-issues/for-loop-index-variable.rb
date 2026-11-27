## update
def foo
  for i in [1, 2, 3]
    return i
  end
  nil
end

def bar
  for s in ["a", "b"]
  end
  s
end

## assert
class Object
  def foo: -> Integer?
  def bar: -> String?
end
