## update
def foo(x:)
  x
end

## assert
class Object
  def foo: (x: untyped) -> untyped
end

## update
def foo(x: 1)
  x
end

## assert
class Object
  def foo: (?x: Integer) -> Integer
end

## update
def foo(x: 1, y:)
  x
end

## assert
class Object
  def foo: (y: untyped, ?x: Integer) -> Integer
end

## update
def foo(**kw)
  kw
end

## assert
class Object
  def foo: (**untyped) -> untyped
end

## update
def foo(x:)
  x
end

foo(x: "str")

## assert
class Object
  def foo: (x: String) -> String
end

## update
def foo(x: 1)
  x
end

foo(x: "str")

## assert
class Object
  def foo: (?x: Integer | String) -> (Integer | String)
end

## update
def foo(a:, b: 1, **c)
  c
end

foo(a: '', b: 1, c: true)

## assert
class Object
  def foo: (a: String, ?b: Integer, **Integer | String | true) -> Hash[:a | :b | :c, Integer | String | true]
end
