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

def test_rest_then_nested
  *a, (b, c) = [1, 2, [3, 4]]
  [a, b, c]
end

def test_rest_then_nested_and_right
  *a, (b, c), d = [1, ["str", :sym], 2.0]
  [a, b, c, d]
end

def test_rest_then_deeper_nesting
  *a, (b, (c, d)) = [1, [2, [3, 4]]]
  [a, b, c, d]
end

def test_rest_then_nested_with_rest
  *a, (b, *rest) = [1, [2, 3, 4]]
  [a, b, rest]
end

def test_rest_then_nested_generic
  *a, (b, c) = [[1, 2], [3, 4]].map {|x| x }
  [a, b, c]
end

## assert
class Object
  def test_nested_destructuring: -> [Integer, Integer, Integer]
  def test_nested_with_strings: -> [String, String, String]
  def test_deeper_nesting: -> [Integer, Integer, Integer, Integer]
  def test_nested_with_rest: -> [Integer, Integer, Array[Integer]]
  def test_nested_with_rest_and_rights: -> [Integer, Integer, Array[Integer], Integer]
  def test_rest_then_nested: -> [Array[Integer], Integer, Integer]
  def test_rest_then_nested_and_right: -> [Array[Integer], String, :sym, Float]
  def test_rest_then_deeper_nesting: -> [Array[Integer], Integer, Integer, Integer]
  def test_rest_then_nested_with_rest: -> [Array[Integer], Integer, Array[Integer]]
  def test_rest_then_nested_generic: -> [Array[[Integer, Integer]], Integer, Integer]
end
