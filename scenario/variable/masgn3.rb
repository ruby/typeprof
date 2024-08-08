## update: test.rb
def check
  *ary = [:a, :b, :c, :d]
  ary
end

## assert
class Object
  def check: -> Array[:a | :b | :c | :d]
end

## update: test.rb
def check
  a, *ary, z = [:a, :b, :c, :d]
  [a, ary, z]
end

## assert
class Object
  def check: -> [:a, Array[:b | :c], :d]
end
