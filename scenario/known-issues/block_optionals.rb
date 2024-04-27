## update
def test_yield
  yield 1, 2
end

def check1
  test_yield do |x, y = :y|
    return [x, y]
  end
  nil
end

def check2
  test_yield do |x, y, z = :z|
    return [x, y, z]
  end
  nil
end

# test_yield do |x, kw: 1|
# etc.

## assert
class Object
  def test_yield: { (Integer, Integer) -> bot } -> bot
  def check1: -> [Integer, Integer]?
  def check2: -> [Integer, Integer, :z]?
end
