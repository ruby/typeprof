## update
def foo(a, b, o1 = 1, o2 = o1)
end

foo(:A, :B, :O1)

## assert
class Object
  def foo: (:A, :B, ?:O1 | Integer, ?:O1 | Integer) -> nil
end

## update
def foo(a, b, o1 = 1, o2 = o1, x, y)
end

foo(:A, :B, :O1, :X, :Y)

## assert
class Object
  def foo: (:A, :B, ?:O1 | Integer, ?:O1 | Integer, :X, :Y) -> nil
end

## update
def foo(a, b, *r)
end

foo(:A, :B, :R1, :R2, :R3)

## assert
class Object
  def foo: (:A, :B, *:R1 | :R2 | :R3) -> nil
end

## update
def foo(a, b, *r, x, y)
end

foo(:A, :B, :R1, :R2, :R3, :X, :Y)

## assert
class Object
  def foo: (:A, :B, *:R1 | :R2 | :R3, :X, :Y) -> nil
end

## update
def foo(a, b, o1 = 1, o2 = o1, *r, x, y)
end

foo(:A, :B, :O1, :O2, :R1, :R2, :R3, :X, :Y)

## assert
class Object
  def foo: (:A, :B, ?:O1 | Integer, ?:O1 | :O2 | Integer, *:R1 | :R2 | :R3, :X, :Y) -> nil
end
