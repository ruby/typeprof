## update: test.rbs
class Foo
  def self.f: (Hash[Symbol, Integer]) -> String | (Hash[Symbol, String]) -> Symbol
end

## update: test.rb
# Hash value type argument causes overload oscillation via the same
# mechanism: empty value type vertex in typecheck_for_module.
def check
  @x = Foo.f({ a: @x })
end

## assert
class Object
  def check: -> untyped
end

## diagnostics
