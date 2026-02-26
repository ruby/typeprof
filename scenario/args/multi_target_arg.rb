## update
def check(z, (x, y))
  [z, y, x]
end

check(1, [1, "str"])

## assert
class Object
  def check: (Integer, [Integer, String]) -> [Integer, String, Integer]
end
