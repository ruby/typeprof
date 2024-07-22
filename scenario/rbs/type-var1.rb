## update: test.rbs
class Foo[X]
  def foo: (X) -> void
end

## update: test.rb
class Foo
  def foo(x) # temporarily "var[X]" is printed
  end
end

## assert: test.rb
class Foo
  def foo: (var[X]) -> nil
end

## update: test.rb
class Foo
  def foo(x)
    x.bar # currently, X is handled like Object
    nil
  end
end

## assert: test.rb
class Foo
  def foo: (var[X]) -> nil
end

## diagnostics
(3,6)-(3,9): undefined method: var[X]#bar

## update: test.rbs
class Foo[X]
  def foo: (X) -> X
end

## update: test.rb
class Foo
  def foo(x)
    x
  end
end

## assert: test.rb
class Foo
  def foo: (var[X]) -> var[X]
end
