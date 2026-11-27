## update
class Foo
  X = 1

  def self.foo = self::X
end

## assert
class Foo
  X: Integer
  def self.foo: -> Integer
end

## update
class Foo
  X = 1

  def foo = self.class::X
end

Foo.new.foo

## assert
class Foo
  X: Integer
  def foo: -> Integer
end
