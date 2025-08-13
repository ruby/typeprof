## update
class Foo
  def initialize(x, y)
    @x = x
    @y = y
  end

  def check(x, y)
  end

  def foo
    @x.is_a?(String) && @y.is_a?(Integer) && check(@x, @y)
  end
end

Foo.new(1, 1)
Foo.new(1, "")
Foo.new("", 1)
Foo.new("", "")

## assert
class Foo
  def initialize: (Integer | String, Integer | String) -> (Integer | String)
  def check: (String, Integer) -> nil
  def foo: -> bool?
end
