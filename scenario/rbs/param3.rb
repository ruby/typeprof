## update: test.rbs
class Object
  def baz: [U] (Array[U]) -> U
end

## update: test.rb
def test3
  baz([1, 2, 3])
end

## assert: test.rb
class Object
  def test3: -> Integer
end