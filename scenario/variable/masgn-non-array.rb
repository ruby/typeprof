## update: test.rb
def check
  *ary = 42
  ary
end

## assert
class Object
  def check: -> Array[Integer]
end

## update: test.rb
def check
  a, *ary, z = 42
  [a, ary, z]
end

## assert
class Object
  def check: -> [Integer, Array[untyped], untyped]
end
