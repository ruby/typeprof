## update
def check
  ["str"].map do |x|
    next x
    next x
    1
  end
end

## assert
class Object
  def check: -> Array[Integer | String]
end
