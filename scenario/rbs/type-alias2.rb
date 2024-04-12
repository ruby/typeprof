## update: test.rbs
class Foo
  type a[T] = Array[T]
  def foo: (a[String]) -> a[Integer]
end

## update: test.rb
def foo
  Foo.new.foo(["str"])
end

## assert
class Object
  def foo: -> Array[Integer]
end
