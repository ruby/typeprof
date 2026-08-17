## update
def foo
  [*1..100]
end
def bar
  [*"A".."Z"]
end

## assert
class Object
  def foo: -> Array[Integer]
  def bar: -> Array[String]
end

## update
def foo(x)
  [*x]
end

foo([:int])
foo(:sym)

## assert
class Object
  def foo: (:sym | [:int]) -> Array[:int | :sym]
end
