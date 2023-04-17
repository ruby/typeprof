## update
def test
  if rand < 0.5
    nil
  else
    [1, "str"]
  end
end

def foo
  a, b = test
  a
end

def bar
  a, b = test
  b
end

## assert
class Object
  def test: -> [Integer, String]?
  def foo: -> Integer?
  def bar: -> String
end