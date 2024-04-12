## update: test.rbs
class C
  def foo: (Integer) -> Integer | (String) -> String
end

## update: test.rb
class C
  def bar
    foo(1)
  end
end

## assert: test.rb
class C
  def bar: -> Integer
end

## update: test.rbs
class C
  def foo: (Integer) -> Float | (String) -> String
end

## assert: test.rb
class C
  def bar: -> Float
end
