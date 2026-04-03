## update
class Point < Struct.new(:x, :y)
end
Point.new(1, "hello").x

## assert
class Point < Struct[untyped]
  def x: -> Integer
  def y: -> String
  def x=: (Integer) -> Integer
  def y=: (untyped) -> untyped
  def initialize: (Integer, String) -> void
  def self.[]: (Integer, String) -> Point
end
