## update: test0.rb
class Foo
  def initialize(x, y)
    @x = x
    @y = y
  end

  def foo
    x
  end

  attr_reader :x, :y
end

## assert: test0.rb
class Foo
  def initialize: (untyped, untyped) -> untyped
  def foo: -> untyped
  def x: -> untyped
  def y: -> untyped
end

## update: test1.rb
Foo.new(1, 1.0)

## assert: test0.rb
class Foo
  def initialize: (Integer, Float) -> Float
  def foo: -> Integer
  def x: -> Integer
  def y: -> Float
end

## update: test1.rb
Foo.new(1.0, 1)

## assert: test0.rb
class Foo
  def initialize: (Float, Integer) -> Integer
  def foo: -> Float
  def x: -> Float
  def y: -> Integer
end
