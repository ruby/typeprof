## update
def create
  x = 1
  y = "str"
  { x:, y: }
end

## assert
class Object
  def create: -> Hash[:x | :y, Integer | String]
end
