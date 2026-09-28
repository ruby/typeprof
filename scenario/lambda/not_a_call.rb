## update
def lambda(&b) = 42
def f = -> { 1 }
class C
  def lambda = "str"
  def g = -> { }
end

## assert
class Object
  def lambda: -> Integer
  def f: -> Proc
end
class C
  def lambda: -> String
  def g: -> Proc
end
