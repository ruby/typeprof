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
  a.foo
end

def test2
  a = A.new
  a.bar = "foo"
  a.bar
end

## assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> String
end

## hover: test.rb:3:4
A#foo= : (Integer | Float) -> Integer | Float

## hover: test.rb:4:4
A#foo : -> Integer

## hover: test.rb:9:4
A#bar= : (String) -> String

## hover: test.rb:10:4
A#bar : -> String
