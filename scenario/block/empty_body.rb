## update
# The parameter of an empty block is its own, not the enclosing x
def outer_local
  x = 1
  ["str"].each {|x| }
  x
end

## assert
class Object
  def outer_local: -> Integer
end
