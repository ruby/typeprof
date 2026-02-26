## update: test.rbs
class A
  attr_reader foo: Integer
  attr_writer foo: Integer | Float

  attr_accessor bar: String
end

## update: test.rb
def test1
  a = A.new
  a.foo = 42.0
#   ^[A]
  a.foo
#   ^[B]
end

def test2
  a = A.new
  a.bar = "foo"
#   ^[C]
  a.bar
#   ^[D]
end

## assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> String
end

## hover: [A]
A#foo= : (Integer | Float) -> Integer | Float

## hover: [B]
A#foo : -> Integer

## hover: [C]
A#bar= : (String) -> String

## hover: [D]
A#bar : -> String
