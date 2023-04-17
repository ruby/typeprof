# update: test.rbs
class C
  def foo: ([Integer]) -> :a
         | ([Integer, Integer]) -> :b
         | ([Integer, String]) -> :c
  end

# update: test.rb
def test1
  C.new.foo([1])
end

def test2
  C.new.foo(["str"])
end

def test3
  C.new.foo([1, 2])
end

def test4
  C.new.foo([1, "str"])
end

def test5
  C.new.foo(["str", "str"])
end

# assert
class Object
  def test1: -> :a
  def test2: -> untyped
  def test3: -> :b
  def test4: -> :c
  def test5: -> untyped
end