## update: test.rbs
module M1
  def foo: () -> :m1
end

module M2
  def foo: () -> :m2
  def bar: () -> :m2
end

module M3
  def foo: () -> :m3
  def bar: () -> :m3
  def baz: () -> :m3
end

class C
  include M1
  prepend M2
  include M3

  def foo: () -> :c
  def bar: () -> :c
  def baz: () -> :c
end

## update: test.rb
def test_foo
  # Should return :m2 (prepended module wins)
  C.new.foo
end

def test_bar
  # Should return :m2 (prepended module wins)
  C.new.bar
end

def test_baz
  # Should return :c (class method overrides included module)
  C.new.baz
end

## assert
class Object
  def test_foo: -> :m2
  def test_bar: -> :m2
  def test_baz: -> :c
end
