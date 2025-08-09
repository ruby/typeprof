## update: test.rbs
module M
  def foo: () -> String
end

class C
  prepend M

  def foo: () -> Integer
end

class Object
  def accept_m: (M) -> String
end

## update: test.rb
def test
  accept_m(C.new)
end

def test2
  C.new.foo
end

## assert
class Object
  def test: -> String
  def test2: -> String
end
