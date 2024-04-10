## update
C = 1
class Foo
  C = 1.0
  def foo
    ::C
  end
end
Foo::Bar = :bar

## assert
C: Integer
class Foo
  Foo::C: Float
  def foo: -> Integer
end
Foo::Bar: :bar
