## update: test.rbs
interface _Fooable
  def foo: (Integer) -> String
end

module M: _Fooable
end

## update: test.rb
class C
  include M
end

def test
  C.new.foo(42)
end

## assert
class C
  include M
end
class Object
  def test: -> String
end
