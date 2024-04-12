## update
def foo(a, b, *r)
end

ary = ["str"].to_a
foo(:A, *ary)

## assert
class Object
  def foo: (:A, String, *String) -> nil
end

## update
def foo(a, b, *r)
end

ary = ["str"].to_a
foo(:A, :B, :C, *ary)

## assert
class Object
  def foo: (:A, :B, *:C | String) -> nil
end

## update
def foo(a, b, o1 = 1, o2 = o1, *r)
end

ary = ["str"].to_a
foo(:A, :B, :C, :D, :E, *ary)

## assert
class Object
  def foo: (:A, :B, ?:C | Integer, ?:C | :D | Integer, *:E | String) -> nil
end

## update
def foo(*r, y, z)
end

ary = ["str"].to_a
foo(*ary, :Z)

## assert
class Object
  def foo: (*String, String, :Z) -> nil
end

## update
def foo(*r, y, z)
end

ary = ["str"].to_a
foo(*ary, :X, :Y, :Z)

## assert
class Object
  def foo: (*:X | String, :Y, :Z) -> nil
end

## update
def foo(a, b, *r, y, z)
end

ary = ["str"].to_a
foo(*ary, :X, :Y, :Z)

## assert
class Object
  def foo: (:X | String, :X | String, *:X | String, :Y, :Z) -> nil
end
