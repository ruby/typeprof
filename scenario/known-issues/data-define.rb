## update
Foo = Data.define(:x, :y)
Foo.new(x: 1, y: "a")

## assert
class Foo < Data
  def initialize: (x: Integer, y: String) -> void
  def x: -> Integer
  def y: -> String
end

## update
class Bar < Data.define(:name)
  def greet = "hi, #{name}"
end

Bar.new(name: "taro").greet

## assert
class Bar < Data
  def initialize: (name: String) -> void
  def name: -> String
  def greet: -> String
end
