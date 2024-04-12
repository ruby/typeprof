## update: tset.rbs
class Object
  def int_or_nil: -> Integer?
end

## update: test.rb
def test
  int_or_nil || raise
end

## assert
class Object
  def test: -> Integer
end
