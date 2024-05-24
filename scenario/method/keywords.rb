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
