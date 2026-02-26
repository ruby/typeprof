## update: test.rbs
class Foo
  def self.f: (*Integer) -> String | (*String) -> Symbol
end

## update: test.rb
# Splat arguments with rest-positional overloads used to cause
# oscillation. The overload fix skips resolution when any splat
# element vertex has no type information, preventing the cycle.
def check
  @args = [42]
  @x = Foo.f(*@args)
  @args = [@x]
end

## assert
class Object
  def check: -> [untyped]
end

## diagnostics
