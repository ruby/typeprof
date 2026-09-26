## update
class Object
  def foo(n) = n
  def self.bar(n) = n

  bar(1)
end

foo(1)

class C
  def foo(n)
  end

  def self.bar(n)
  end
end

## assert
class Object < BasicObject
  def foo: (Integer) -> Integer
  def self.bar: (Integer) -> Integer
end
class C
  def foo: (untyped) -> nil
  def self.bar: (untyped) -> nil
end
