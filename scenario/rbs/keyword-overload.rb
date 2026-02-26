## update: test.rbs
class C
  def foo: (key: Integer) -> Integer | (key: String) -> String
end

## update: test.rb
class C
  def bar
    foo(key: 1)
  end
  def baz
    foo(key: "s")
  end
end

## assert: test.rb
class C
  def bar: -> Integer
  def baz: -> String
end
