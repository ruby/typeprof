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
