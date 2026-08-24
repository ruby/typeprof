## update: test.rbs
class Object
  def pick: (Integer) -> Integer
          | (*Integer) -> String
end

## update: test.rb
def test_fixed
  pick(1)
end

def test_splat
  ary = [1, 2]
  pick(*ary)
end

## assert
class Object
  def test_fixed: -> Integer
  def test_splat: -> String
end
