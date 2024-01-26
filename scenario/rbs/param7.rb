## update: test.rbs
class C[X]
end

class Object
  def get_c_int: -> C[Integer]
  def accept_c: (C[String]) -> :str
              | (C[Integer]) -> :int
              | (C[Numeric]) -> :num
              | (C[untyped]) -> :untyped
end

## update: test.rb
def test
  accept_c(get_c_int)
end

## assert
class Object
  def test: -> (:int | :num | :untyped)
end
