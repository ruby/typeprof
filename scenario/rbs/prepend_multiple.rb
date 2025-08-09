## update: test.rbs
module M1
  def foo: () -> :m1
end

module M2
  def foo: () -> :m2
  def bar: () -> :m2
end

class C
  prepend M1
  prepend M2

  def foo: () -> :c
  def bar: () -> :c
end

class Object
  def accept_m1: (M1) -> String
  def accept_m2: (M2) -> String
end

## update: test.rb
def test_foo
  C.new.foo
end

def test_bar
  C.new.bar
end

def test_type_m1
  accept_m1(C.new)
end

def test_type_m2
  accept_m2(C.new)
end

## assert
class Object
  def test_foo: -> :m2
  def test_bar: -> :m2
  def test_type_m1: -> String
  def test_type_m2: -> String
end
