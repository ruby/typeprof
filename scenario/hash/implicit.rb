## update
def create
  x = 1
  y = "str"
  { x:, y: }
end

## assert
class Object
  def create: -> { x: Integer, y: String }
end
