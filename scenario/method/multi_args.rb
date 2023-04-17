## update
class Foo
  def initialize(x, y, z)
    @x = x
    @y = y
    @z = z
  end
end

Foo.new(1, 1.0, "String")

## assert
class Foo
  def initialize: (Integer, Float, String) -> String
end