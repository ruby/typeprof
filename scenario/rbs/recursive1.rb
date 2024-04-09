## update
class Foo
  def initialize
    @elem = []
  end

  def foo
    @elem = @elem + [1]
  end
end

## assert
class Foo
  def initialize: -> []
  def foo: -> Array[Integer]
end
