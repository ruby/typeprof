## update: test.rbs
class C
  def foo: (**Integer) -> Integer | (**String) -> String
end

## update: test.rb
class C
  def bar
    foo(x: 1, y: 2)
  end
  def baz
    foo(x: "a", y: "b")
  end
end

## assert: test.rb
class C
  def bar: -> Integer
  def baz: -> String
end
