## update: test.rbs
interface _Fooable[X]
  def foo: (Integer) -> [X, String]
end

module M[X]: _Fooable[X]
end

module N: M[Float]
end

## update: test.rb
class C
  include N
end

def test
  C.new.foo(42)
end

## assert
class C
  include N
end
class Object
  def test: -> [Float, String]
end
