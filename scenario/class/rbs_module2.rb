## update: test.rbs
module M[X]
  def foo: -> X
end

class Foo
  include M[Integer]
  include M[String]
end

## update: test.rb
def test
  Foo.new.foo
end

## assert: test.rb
class Object
  def test: -> Integer
end