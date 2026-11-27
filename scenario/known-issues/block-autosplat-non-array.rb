## update
# A sole non-Array value is bound to the first parameter, not splatted.
def yield_one
  yield 1
end

def check1 = yield_one {|x, y| [x, y] }
def check2 = [1, "str"].map {|x, y| x }
def check3 = [[1, 2], :sym].map {|x, y| x }

## assert
class Object
  def yield_one: { (Integer) -> [Integer, nil] } -> [Integer, nil]
  def check1: -> [Integer, nil]
  def check2: -> Array[Integer | String]
  def check3: -> Array[:sym | Integer]
end
