## update
class ::Foo
  def foo = 1
end

## assert
class Foo
  def foo: -> Integer
end

## update
module M
  class ::Bar
    def bar = 1
  end
end

## assert
module M
  class ::Bar
    def bar: -> Integer
  end
end

## update
module M
end

class ::M::Baz
  def baz = 1
end

## assert
module M
end
class M::Baz
  def baz: -> Integer
end
