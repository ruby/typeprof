## update
def test
  h = { a: 1, b: 2 }
  h.key?(:a)
  h.key?("not a symbol")
  h.key?(Object.new)
end

test

## assert
class Object
  def test: -> bool
end

## diagnostics
