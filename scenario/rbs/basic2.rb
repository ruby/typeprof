## update: test.rbs
class C
  def foo: (Integer) -> Integer
end

## update: test.rb
class C
  def foo(n)
    bar(n)
  end

  def bar(n)
  end
end

## assert: test.rb
class C
  def foo: (Integer) -> nil
  def bar: (Integer) -> nil
end
