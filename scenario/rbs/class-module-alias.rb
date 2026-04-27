## update: test.rbs
class Foo
  def foo: () -> Integer
end
class Bar = Foo
module M
  def m: () -> String
end
module N = M

## update: test.rb
def test1
  Foo.new.foo
end

## assert: test.rb
class Object
  def test1: -> Integer
end

## diagnostics: test.rb
