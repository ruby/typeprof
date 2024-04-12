## update: test0.rbs
class Foo
  def self.foo: (singleton(A)) -> :foo_a | (singleton(::A)) -> :top_a
end

## update: test1.rbs
class A
end
class Foo
  class A
  end
end

## update: test.rb
def test1
  Foo.foo(Foo::A)
end

def test2
  Foo.foo(A)
end

## assert: test.rb
class Object
  def test1: -> :foo_a
  def test2: -> :top_a
end
