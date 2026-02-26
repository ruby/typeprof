## update: test.rbs
class Foo
  def self.f: ([Integer]) -> String | ([String]) -> Symbol
end

## update: test.rb
# Tuple element typecheck causes oscillation via the same mechanism
# as generic type argument oscillation: empty element vertex makes
# typecheck return true for all overloads.
def check
  @x = Foo.f([@x])
end

## assert
class Object
  def check: -> untyped
end

## diagnostics
