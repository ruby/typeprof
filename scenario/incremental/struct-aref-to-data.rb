## update
Pt = Struct.new(:x, :y)
def f = Pt[1, 2]

## diagnostics

## assert
class Pt
  def x: -> Integer
  def x=: (untyped) -> untyped
  def y: -> Integer
  def y=: (untyped) -> untyped
  def initialize: (?Integer, ?Integer) -> void
  def self.[]: (?Integer, ?Integer) -> Pt
end
class Object
  def f: -> Pt
end

## update
Pt = Data.define(:x, :y)
def f = Pt[1, 2]

## diagnostics
(2,10)-(2,16): undefined method: singleton(Pt)#[]

## assert
class Pt
  def x: -> untyped
  def y: -> untyped
  def initialize: (x: untyped, y: untyped) -> void
end
class Object
  def f: -> untyped
end
