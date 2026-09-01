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

## update
def foo(x)
  [*x]
end

foo([1])
foo(nil)

## assert
class Object
  def foo: ([Integer]?) -> Array[Integer]
end

## update
class C
  def to_ary
    [1]
  end
end

def foo(x)
  [*x]
end

foo(C.new)

## assert
class C
  def to_ary: -> [Integer]
end
class Object
  def foo: (C) -> Array[C]
end
