# update
class C
  X = 1
end

class D < C
end

def foo(_)
  D::X
end

# assert
class C
  C::X: Integer
end
class D < C
end
class Object
  def foo: (untyped) -> Integer
end