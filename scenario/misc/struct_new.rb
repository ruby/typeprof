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

## update
# https://github.com/ruby/typeprof/issues/458
# A user-defined initialize in the block overrides the auto-generated one,
# so the RBS output must contain only the user-defined signature.
Pt = Struct.new(:x, :y) do
  def initialize(x = 0, y = 0)
    super
  end
end
Pt.new
Pt.new(3, 4)

## assert
class Pt
  def x: -> Integer
  def x=: (untyped) -> untyped
  def y: -> Integer
  def y=: (untyped) -> untyped
  def self.[]: (Integer, Integer) -> Pt
  def initialize: (?Integer, ?Integer) -> void
end

## update
Dog = Struct.new(:name, :age) do
  def initialize(name, age)
    super(name.to_s, age.to_i)
  end
end
Dog.new("fred", "5")

## assert
class Dog
  def name: -> String
  def name=: (untyped) -> untyped
  def age: -> Integer
  def age=: (untyped) -> untyped
  def self.[]: (String, Integer) -> Dog
  def initialize: (String, String) -> void
end

## update
D = Data.define(:name, :age) do
  def initialize(name:, age:)
    super(name: name.to_s, age: age.to_i)
  end
end
D.new(name: "fred", age: "5")

## assert
class D
  def name: -> String
  def age: -> Integer
  def initialize: (name: String, age: String) -> void
end

## update
Pt = Struct.new(:x, :y)
class Pt
  def initialize(x = 0, y = 0)
    super
  end
end
Pt.new(3, 4)

## assert
class Pt
  def x: -> Integer
  def x=: (untyped) -> untyped
  def y: -> Integer
  def y=: (untyped) -> untyped
  def self.[]: (Integer, Integer) -> Pt
end
class Pt
  def initialize: (?Integer, ?Integer) -> void
end
