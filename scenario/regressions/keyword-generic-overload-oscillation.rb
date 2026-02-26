## update: test.rbs
class Foo
  def self.f: (key: Array[Integer]) -> String | (key: Array[String]) -> Symbol
end

## update: test.rb
# Keyword arguments with generic types could cause oscillation
# if the keyword arg has empty type parameter vertices.
def check
  @x = Foo.f(key: [@x])
end

## assert
class Object
  def check: -> untyped
end

## diagnostics
