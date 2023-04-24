## update
def foo(a, b, o1 = 1, o2 = o1)
end

ary = ["str"].to_a
foo(:A, *ary)

## assert
class Object
  def foo: (:A, String, ?Integer | String, ?Integer | String) -> nil
end

## update
def foo(a, b, o1 = 1, o2 = o1)
end

ary = ["str"].to_a
foo(:A, :B, :C, *ary)

## assert
class Object
  def foo: (:A, :B, ?:C | Integer, ?:C | Integer | String) -> nil
end

## update
def foo(a, b, o1 = 1, o2 = o1)
end

ary = ["str"].to_a
foo(:A, :B, :C, *ary)

## assert
class Object
  def foo: (:A, :B, ?:C | Integer, ?:C | Integer | String) -> nil
end

## update
def foo(o1 = 1, o2 = o1, y, z)
end

ary = ["str"].to_a
foo(*ary, :Z)

## assert
class Object
  def foo: (?Integer | String, ?Integer | String, String, :Z) -> nil
end

## update
def foo(o1 = 1, o2 = o1, y, z)
end

ary = ["str"].to_a
foo(*ary, :X, :Y, :Z)

## assert
class Object
  def foo: (?:X | Integer | String, ?:X | Integer | String, :Y, :Z) -> nil
end
