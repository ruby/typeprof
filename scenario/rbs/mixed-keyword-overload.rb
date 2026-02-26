## update: test.rbs
class C
  def foo: (mode: :read, **Integer) -> Array[Integer]
         | (mode: :write, **String) -> Array[String]
end

## update: test.rb
class C
  def bar
    foo(mode: :read, x: 1)
  end
  def baz
    foo(mode: :write, x: "a")
  end
end

## assert: test.rb
class C
  def bar: -> Array[Integer]
  def baz: -> Array[String]
end
