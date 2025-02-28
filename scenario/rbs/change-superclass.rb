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
  def test: -> :foo_a
end

## diagnostics: test.rb
(6,6)-(6,9): wrong type of arguments

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

## diagnostics: test.rb
