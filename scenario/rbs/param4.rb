## update: test.rbs
class Foo[Y]
end
class Bar[X] < Foo[[X, X]]
  def self.create: -> Bar[Integer]
end
class Object
  def foo: [Z] (Foo[Z]) -> Z
end

## update: test.rb
def test
  foo(Bar.create)
end