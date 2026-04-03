## update
Foo = Struct.new(:bar, :baz)
f = Foo.new(1, "hello")
f.bar
f.baz
f.bar = 2
g = Foo[3, "world"]

## assert
class Foo
  def bar: -> Integer
  def bar=: (Integer) -> Integer
  def baz: -> String
  def baz=: (untyped) -> untyped
  def initialize: (Integer, String) -> void
  def self.[]: (Integer, String) -> Foo
end

## update
Pt = Data.define(:x, :y)
p = Pt.new(x: 1, y: "hello")
p.x
p.y

## assert
class Pt
  def x: -> Integer
  def y: -> String
  def initialize: (x: Integer, y: String) -> void
end

## update
Bar = Struct.new(:n) do
  def double
    n * 2
  end
end
Bar.new(5).double

## assert
class Bar
  def n: -> Integer
  def n=: (untyped) -> untyped
  def initialize: (Integer) -> void
  def self.[]: (Integer) -> Bar
  def double: -> Integer
end

## update
# The Struct member `v` is not a real Ruby ivar, so a user-written @v inside
# the block body must not share the member's type.
Baz = Struct.new(:v) do
  def set_label
    @v = "label"
  end
  def ivar
    @v
  end
end
Baz.new(42).v
Baz.new(42).ivar

## assert
class Baz
  def v: -> Integer
  def v=: (untyped) -> untyped
  def initialize: (Integer) -> void
  def self.[]: (Integer) -> Baz
  def set_label: -> String
  def ivar: -> String
end
