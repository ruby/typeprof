## update
class Foo
end

class Bar
  #: -> Foo[Integer]
  def foo = Foo.new
end

## assert
class Foo
end
class Bar
  def foo: -> Foo[Integer]
end
