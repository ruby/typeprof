## update
def check1 = [1].map {|*b| b }
def check2 = [[1, "str"]].map {|a, *b| b }
def check3 = [[1, "str", :sym]].map {|a, *b, c| c }

## assert
class Object
  def check1: -> Array[Array[Integer]]
  def check2: -> Array[Array[String]]
  def check3: -> Array[:sym]
end
