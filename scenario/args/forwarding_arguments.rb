## update
def foo(...)
  nil
end

## assert
class Object
  def foo: (*untyped, **untyped) -> nil
end

## update
def foo(a, ...)
  a
end

foo(1)

## assert
class Object
  def foo: (Integer, *untyped, **untyped) -> Integer
end

## update
def foo(...)
  bar(...)
end

def bar
  1
end

foo()

## assert
class Object
  def foo: (*untyped, **untyped) -> Integer
  def bar: -> Integer
end

## update
def foo(x, ...)
  bar(x, ...)
end

def bar(a, b)
  [a, b]
end

foo(1, 2)

## assert
class Object
  def foo: (Integer, *Integer, **untyped) -> [Integer, Integer]
  def bar: (Integer, Integer) -> [Integer, Integer]
end

## update
def foo(...)
  bar(...)
end

def bar
end

## diagnostics

## update
def foo(...)
  bar(1, ...)
end

def bar(a, *b, **c)
  [a, b, c]
end

foo(x: 4, y: 5)

## assert
class Object
  def foo: (*untyped, **Integer) -> [Integer, Array[untyped], { x: Integer, y: Integer }]
  def bar: (Integer, *untyped, **Integer) -> [Integer, Array[untyped], { x: Integer, y: Integer }]
end

## update
def foo(...)
  extra = "x"
  bar(extra, ...)
end

def bar(a, *b, **c)
  [a, b, c]
end

foo(2, x: 4, y: 5)

## assert
class Object
  def foo: (*Integer, **Integer) -> [String, Array[Integer], { x: Integer, y: Integer }]
  def bar: (String, *Integer, **Integer) -> [String, Array[Integer], { x: Integer, y: Integer }]
end

## update
def foo(...)
  bar(...)
end

def bar(*a, **b)
  [a, b]
end

foo(1, x: 4, y: 5)

## assert
class Object
  def foo: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
  def bar: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
end

## update
def foo(...)
  1.times { bar(...) }
end

def bar(*a, **b)
  [a, b]
end

foo(1, x: 4, y: 5)

## assert
class Object
  def foo: (*Integer, **Integer) -> Integer
  def bar: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
end
