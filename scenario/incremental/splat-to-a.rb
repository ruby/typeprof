## update
class C
end

def foo(x)
  [*x]
end

foo(C.new)

## assert
class C
end
class Object
  def foo: (C) -> Array[C]
end

## update
class C
  def to_a
    [1]
  end
end

def foo(x)
  [*x]
end

foo(C.new)

## assert
class C
  def to_a: -> [Integer]
end
class Object
  def foo: (C) -> Array[Integer]
end

## update
class C
end

def foo(x)
  [*x]
end

foo(C.new)

## assert
class C
end
class Object
  def foo: (C) -> Array[C]
end
