## update
def check1((a, *b))
  b
end

check1([1, 2, 3])

def check2((a, *b, c))
  c
end

check2([1, 2, :sym])

def check3((a, (b, c)))
  c
end

check3([1, [2, "str"]])

## assert
class Object
  def check1: ([Integer, Integer, Integer]) -> Array[Integer]
  def check2: ([Integer, Integer, :sym]) -> :sym
  def check3: ([Integer, [Integer, String]]) -> String
end

## update
def check
  [[1, "str", :sym]].map {|(a, *b)| b }
end

## assert
class Object
  def check: -> Array[Array[:sym | String]]
end
