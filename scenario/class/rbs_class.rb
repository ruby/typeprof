## update: test.rbs
class C
  def foo: (singleton(C)) -> :ok
  def bar: (Class) -> :ok
end

## update: test.rb
def test1
  C.new.foo(C)
end

def test2
  C.new.foo(C)
end

## assert
class Object
  def test1: -> :ok
  def test2: -> :ok
end
