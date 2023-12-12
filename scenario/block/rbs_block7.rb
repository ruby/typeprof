## update: test.rbs
class Foo
  def foo: { () -> Integer } -> void
end

## update: test.rb
Foo.new.foo do
  "str"
end

## diagnostics: test.rb
(2,2)-(2,7): expected: Integer; actual: String

## update: test.rbs
class Foo
  def foo: { () -> String } -> void
end

## diagnostics: test.rb
