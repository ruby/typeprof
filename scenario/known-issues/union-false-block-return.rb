## update
# Enumerable#filter_map: [U] () { (E elem) -> (nil | false | U) } -> Array[U]
# A block that can return `false` makes U lose every other type, because the
# `false` member of the union accepts the whole return vertex.
def check1 = [1, 2].filter_map {|n| n.even? ? n : false }
def check2 = [1, 2].filter_map {|n| n.even? ? n.to_s : false }

## assert
class Object
  def check1: -> Array[Integer]
  def check2: -> Array[String]
end
