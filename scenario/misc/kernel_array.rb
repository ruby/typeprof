## update
def from_range
  Array(1..5)
end

def from_literal_array
  Array([1, 2, 3])
end

def from_integer
  Array(42)
end

## assert
class Object
  def from_range: -> Array[Integer]
  def from_literal_array: -> [Integer, Integer, Integer]
  def from_integer: -> Array[Integer]
end
