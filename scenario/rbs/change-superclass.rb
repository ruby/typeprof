## update: test0.rbs
class Foo
  def self.foo: (A) -> :foo_a
end

## update: test.rb
class A
end
class B
end
def test
  Foo.foo(B.new)
end

## assert: test.rb
class A
end
class B
end
class Object
  def test: -> untyped
end

## update: test.rb
class A
end
class B < A
end
def test
  Foo.foo(B.new)
end

## assert: test.rb
class A
end
class B < A
end
class Object
  def test: -> :foo_a
end