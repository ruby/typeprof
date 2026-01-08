## update: test.rbs
class Foo[X, Y = Integer]
  def get_x: -> X
  def get_y: -> Y
end

class Object
  def create_foo_str_int: -> Foo[String]
  def create_foo_str_str: -> Foo[String, String]
end

## update: test.rb
def check1
  x = create_foo_str_int
  [x.get_x, x.get_y]
end

def check2
  x = create_foo_str_str
  [x.get_x, x.get_y]
end

## assert
class Object
  def check1: -> [String, Integer]
  def check2: -> [String, String]
end
