## update
def bar(n)
  n
end

def test
  m = method(:bar)
  m.call(1)
end

## assert
class Object
  def bar: (Integer) -> Integer
  def test: -> Integer
end

## update
class Foo
  def baz(s)
    s
  end

  def test
    m = method(:baz)
    m.call("hello")
  end
end

## assert
class Foo
  def baz: (String) -> String
  def test: -> String
end

## update
def target(n)
  n
end

def call_it(m)
  m.call(1)
end

def test2
  call_it(method(:target))
end

## assert
class Object
  def target: (Integer) -> Integer
  def call_it: (Method) -> Integer
  def test2: -> Integer
end

## update
class Bar
  def a(n)
    n.to_s
  end

  def b(n)
    n.to_s
  end

  def test
    methods = [method(:a), method(:b)]
    methods.each { |m| m.call(1) }
  end
end

## assert
class Bar
  def a: (Integer) -> String
  def b: (Integer) -> String
  def test: -> Array[Method]
end

## update
class Baz
  def work(n)
    n
  end

  def get_method
    method(:work)
  end
end

## assert
class Baz
  def work: (untyped) -> untyped
  def get_method: -> Method
end
