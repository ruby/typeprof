## update: test.rbs
class Foo
  def check: () -> Array[bool]
end

## update: test.rb
def foo(node)
  node = Foo.new
  while true
    node, = node.check
  end
end

foo

## assert
class Object
  def foo: (untyped) -> nil
end
