## update
def foo(n)
  n ? 1 : "str"
end
def bar(n)
  n = 1 if n
  n
end
def baz(n)
  n = 1 unless n
end

## assert
class Object
  def foo: (untyped) -> (Integer | String)
  def bar: (untyped) -> Integer
  def baz: (untyped) -> Integer?
end

## update
def foo(n)
  n ? 1 : "str"
end
def bar(n)
  n = 1 if n
  n
end
def baz(n)
  n = 1 unless n
end

## assert
class Object
  def foo: (untyped) -> (Integer | String)
  def bar: (untyped) -> Integer
  def baz: (untyped) -> Integer?
end