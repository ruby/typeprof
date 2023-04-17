## update: test.rbs
class C
  def foo: (:a) -> :ok
  def bar: (Symbol) -> :ok
end

## update: test.rb
def test1
  C.new.foo(:a)
end

def test2
  C.new.foo(:b)
end

def test3
  C.new.bar(:a)
end

def test4
  C.new.bar(:b)
end

## assert
class Object
  def test1: -> :ok
  def test2: -> untyped
  def test3: -> :ok
  def test4: -> :ok
end