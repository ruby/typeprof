## update
class A
  def foo(x) = x + 1
end

class B < A
  def foo(x)
    super
  end
end

B.new.foo(1)

## assert
class A
  def foo: (Integer) -> Integer
end
class B < A
  def foo: (Integer) -> Integer
end
