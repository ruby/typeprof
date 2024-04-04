## update: test.rbs
interface _Fooable
  def foo: -> :FOO
end

interface _Barable
  def bar: -> :BAR
end

module M: _Fooable, _Barable
end

## update: test.rb
class C
  include M
end

def test
  [C.new.foo, C.new.bar]
end

## assert
class C
  include M
end
class Object
  def test: -> [:FOO, :BAR]
end
