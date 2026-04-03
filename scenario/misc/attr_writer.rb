## update
class Foo
  attr_writer :x

  def get_x
    @x
  end
end

Foo.new.x = 1
Foo.new.get_x

## assert
class Foo
  def x=: (Integer) -> Integer
  def get_x: -> Integer
end
