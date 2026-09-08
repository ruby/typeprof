## update: test.rbs
class A[E]
  def a: () -> E
end

class B[U]
  @x: U
  def x: () -> U
end

## update: test2.rbs
# Reopen with a different type parameter name
class B[T] < A[T]
  @y: T
  def y: () -> T
end

class Object
  def b: () -> B[String]
end

## update: test.rb
def f = b.a
def g = b.x
def h = b.y

## assert
class Object
  def f: -> String
  def g: -> String
  def h: -> String
end
