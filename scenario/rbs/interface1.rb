## update: test.rbs
interface _Foo
  def foo: (Integer) -> String
end

class Object
  def create_foo: -> _Foo
end

## update: test.rb
def test
  x = create_foo
end

## assert
class Object
  def test: -> _Foo
end

## update: test.rb

def test
  x = create_foo
  x.foo(42)
end

## assert
class Object
  def test: -> String
end