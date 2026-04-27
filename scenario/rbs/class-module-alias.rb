## update: test.rbs
class Foo
  def foo: () -> Integer
end
class Bar = Foo
module M
  def m: () -> String
  CONST: Symbol
end
module N = M

## update: test.rb
def test1
  Foo.new.foo
end

def test2
  Bar.new.foo
end

def test3
  N::CONST
end

class UseN
  include N

  def test4
    m
  end
end

## assert: test.rb
class Object
  def test1: -> Integer
  def test2: -> Integer
  def test3: -> Symbol
end
class UseN
  include M
  def test4: -> String
end

## diagnostics: test.rb
