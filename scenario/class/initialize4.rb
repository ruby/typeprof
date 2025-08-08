## update: test.rbs
class Foo[X, Y]
  def initialize: (Array[X], Array[Y]) -> void
end
class Bar[X, Y]
  def initialize: (Array[Y], Array[X]) -> void
end

## update: test.rb
def check1
  Foo.new([1], ["foo"])
end
def check2
  Bar.new([1], ["foo"])
end

## assert
class Object
  def check1: -> Foo[Integer, String]
  def check2: -> Bar[String, Integer]
end
