## update
def bar(x)
end

def foo(x, y)
  bar()
end

foo(1, 2)

## assert
class Object
  def bar: (untyped) -> nil
  def foo: (Integer, Integer) -> untyped
end

## update
def bar(x)
end

def foo(x, y)
  bar(x)
end

foo(1, 2)

## assert
class Object
  def bar: (Integer) -> nil
  def foo: (Integer, Integer) -> nil
end

## update
def bar(x)
end

def foo(x, y)
  bar(x, y)
end

foo(1, 2)

## assert
class Object
  def bar: (untyped) -> nil
  def foo: (Integer, Integer) -> untyped
end

## update
def bar(x)
end

def foo(x, y)
  bar(x)
end

foo(1, 2)

## assert
class Object
  def bar: (Integer) -> nil
  def foo: (Integer, Integer) -> nil
end