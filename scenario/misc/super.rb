## update: test.rbs
class C
  def foo: (Integer) -> :int
         | (String) -> :str
end

## update: test.rb
class D1 < C
  def foo
    super(1)
  end
end

class D2 < C
  def foo
    super("str")
  end
end

## assert
class D1 < C
  def foo: -> :int
end
class D2 < C
  def foo: -> :str
end

## update
class StringifyKeyHash < Hash
  def [](key)
    super(key.to_s)
  end
end

## assert
class StringifyKeyHash < Hash
  def []: (untyped) -> untyped
end

## update
class SuperBase
  def foo(*a, **b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(...)
    super(...)
  end
end

SuperChild.new.foo(1, x: 4, y: 5)

## assert
class SuperBase
  def foo: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
end
class SuperChild < SuperBase
  def foo: (*Integer, **Integer) -> [Array[Integer], { x: Integer, y: Integer }]
end

## update
class SuperBase
  def foo
    1
  end
end

class SuperChild < SuperBase
  def foo(...)
    super(...)
  end
end

SuperChild.new.foo()

## assert
class SuperBase
  def foo: -> Integer
end
class SuperChild < SuperBase
  def foo: (*untyped, **untyped) -> Integer
end

## update
class SuperBase
  def foo(a)
    a
  end
end

class SuperChild < SuperBase
  def foo(x, ...)
    super(...)
  end
end

SuperChild.new.foo(1, 2)

## assert
class SuperBase
  def foo: (Integer) -> Integer
end
class SuperChild < SuperBase
  def foo: (Integer, *Integer, **untyped) -> Integer
end

## update
class SuperBase
  def foo(a, *b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(...)
    super(1, ...)
  end
end

SuperChild.new.foo()

## assert
class SuperBase
  def foo: (Integer, *untyped) -> [Integer, Array[untyped]]
end
class SuperChild < SuperBase
  def foo: (*untyped, **untyped) -> [Integer, Array[untyped]]
end

## update
class SuperBase
  def foo(a, b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(x, ...)
    super(x, ...)
  end
end

SuperChild.new.foo(1, 2)

## assert
class SuperBase
  def foo: (Integer, Integer) -> [Integer, Integer]
end
class SuperChild < SuperBase
  def foo: (Integer, *Integer, **untyped) -> [Integer, Integer]
end

## update
class SuperBase
  def foo(a, b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(a = 1, b = "str")
    super
  end
end

SuperChild.new.foo

## assert
class SuperBase
  def foo: (Integer, String) -> [Integer, String]
end
class SuperChild < SuperBase
  def foo: (?Integer, ?String) -> [Integer, String]
end

## diagnostics

## update
class SuperBase
  def foo(a, b, k:)
    [a, b, k]
  end
end

class SuperChild < SuperBase
  def foo(a, b = 1, k:)
    a = "str"
    [1].each { b = :sym }
    k = 1.0
    super
  end
end

SuperChild.new.foo(1, k: 1)

## assert
class SuperBase
  def foo: (String, :sym | Integer, k: Float) -> [String, :sym | Integer, Float]
end
class SuperChild < SuperBase
  def foo: (Integer, ?Integer, k: Integer) -> [String, :sym | Integer, Float]
end

## update
class SuperBase
  def foo(a, *b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(a, *b)
    b = [:sym]
    super
  end
end

SuperChild.new.foo(1, "str")

## assert
class SuperBase
  def foo: (Integer, *:sym) -> [Integer, Array[:sym]]
end
class SuperChild < SuperBase
  def foo: (Integer, *String) -> [Integer, Array[:sym]]
end

## update
class SuperBase
  def foo(a, b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(a = 1, b)
    b = "str"
    super
  end
end

SuperChild.new.foo(:sym)

## assert
class SuperBase
  def foo: (Integer, String) -> [Integer, String]
end
class SuperChild < SuperBase
  def foo: (?Integer, :sym) -> [Integer, String]
end

## update
class SuperBase
  def foo(a, b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo((a, b), c = "str")
    super
  end
end

SuperChild.new.foo([1, 2])

## assert
class SuperBase
  def foo: ([Integer, Integer], String) -> [[Integer, Integer], String]
end
class SuperChild < SuperBase
  def foo: ([Integer, Integer], ?String) -> [[Integer, Integer], String]
end

## update
class SuperBase
  def foo(*a, **k)
    [a, k]
  end
end

class SuperChild < SuperBase
  def foo(*, **)
    super
  end
end

SuperChild.new.foo(1, x: 2)

## assert
class SuperBase
  def foo: (*Integer, **Integer) -> [Array[Integer], { x: Integer }]
end
class SuperChild < SuperBase
  def foo: (*Integer, **untyped | Integer) -> [Array[Integer], { x: Integer }]
end

## update
class SuperBase
  def foo(a, b)
    [a, b]
  end
end

class SuperChild < SuperBase
  def foo(...)
    super
  end
end

SuperChild.new.foo(1, 2)

## assert
class SuperBase
  def foo: (Integer, Integer) -> [Integer, Integer]
end
class SuperChild < SuperBase
  def foo: (*Integer, **untyped) -> [Integer, Integer]
end

## update
class SuperBase
  def foo(a)
    a
  end
end

class SuperChild < SuperBase
  def foo(a)
    f = ->(a) { a = "str"; super }
    f.call(1)
  end
end

SuperChild.new.foo(1)

## assert
class SuperBase
  def foo: (Integer) -> Integer
end
class SuperChild < SuperBase
  def foo: (Integer) -> Integer
end
