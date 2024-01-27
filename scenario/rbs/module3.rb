## update: test.rbs
module M[X]
end

class C[X]
  include M[X]
end

class D < C[Integer]
end

class Object
  def accept_m: (M[String]) -> :str
              | (M[Integer]) -> :int
              | (M[Numeric]) -> :num
              | (M[untyped]) -> :untyped
end

## update: test.rb
def test
  accept_m(D.new)
end

## assert
class Object
  def test: -> (:int | :num | :untyped)
end
