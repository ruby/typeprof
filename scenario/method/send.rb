## update
class Foo
  def bar(n)
    n
  end

  def test
    __send__(:bar, 1)
  end
end

## assert
class Foo
  def bar: (Integer) -> Integer
  def test: -> Integer
end

## update
class Foo2
  def greet(s)
    s
  end

  def test
    public_send(:greet, "hello")
  end
end

## assert
class Foo2
  def greet: (String) -> String
  def test: -> String
end

## update
class Foo3
  def add(a, b)
    a
  end

  def test
    send(:add, 1, 2)
  end
end

## assert
class Foo3
  def add: (Integer, Integer) -> Integer
  def test: -> Integer
end

## update
class Foo4
  def foo(n)
    n
  end

  def bar(n)
    n.to_s
  end

  def test
    ary = [:foo, :bar]
    ary.each { send(it, 1) }
  end
end

## assert
class Foo4
  def foo: (Integer) -> Integer
  def bar: (Integer) -> String
  def test: -> Array[:bar | :foo]
end

## update
class Foo5
  def bar(n)
    n
  end

  def test
    send(*[:bar, 1])
  end
end

## assert
class Foo5
  def bar: (Integer) -> Integer
  def test: -> Integer
end

## update
class Foo6
  def bar(a, b)
    a
  end

  def test
    send(*[:bar], 1, 2)
  end
end

## assert
class Foo6
  def bar: (Integer, Integer) -> Integer
  def test: -> Integer
end

## update
class Foo7
  def foo(n)
    n
  end

  def test
    ary = []
    ary << :foo
    send(*ary, 1)
  end
end

## assert
class Foo7
  def foo: (Integer) -> Integer
  def test: -> Integer
end

## update
class Foo8
  def bar(a, b)
    a
  end

  def test
    send(*[:bar, 1, 2].to_a)
  end
end

## assert
class Foo8
  def bar: (untyped, untyped) -> untyped
  def test: -> untyped
end
