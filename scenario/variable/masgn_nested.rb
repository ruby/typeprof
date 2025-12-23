## update
def test_nested_destructuring
  a, (b, c) = [1, [2, 3]]
  [a, b, c]
end

def test_nested_with_strings
  x, (y, z) = ["foo", ["bar", "baz"]]
  [x, y, z]
end

def test_deeper_nesting
  a, (b, (c, d)) = [1, [2, [3, 4]]]
  [a, b, c, d]
end

def test_nested_with_rest
  a, (b, *rest) = [1, [2, 3, 4]]
  [a, b, rest]
end

def test_nested_with_rest_and_rights
  a, (b, *rest, c) = [1, [2, 3, 4, 5]]
  [a, b, rest, c]
end

## assert
class Object
  def test_nested_destructuring: -> [Integer, Integer, Integer]
  def test_nested_with_strings: -> [String, String, String]
  def test_deeper_nesting: -> [Integer, Integer, Integer, Integer]
  def test_nested_with_rest: -> [Integer, Integer, Array[Integer]]
  def test_nested_with_rest_and_rights: -> [Integer, Integer, Array[Integer], Integer]
end
