## update: test.rbs
class Foo[X]
  def foo: -> X
  def self.create_int_foo: -> Foo[Integer]
end

## update: test.rb
def test
  Foo.create_int_foo.foo
end

## assert: test.rb
class Object
  def test: -> Integer
end
