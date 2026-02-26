## update: test.rbs
class Foo
  def self.f: (*Integer) -> String | (*String) -> Symbol
end

## update: test.rb
# Minimal reproduction: unseeded splat overload oscillation.
# The splat array's element vertex is empty, triggering the
# skip in overload resolution.
def check
  @x = Foo.f(*[@x])
end

## assert
class Object
  def check: -> untyped
end

## diagnostics
