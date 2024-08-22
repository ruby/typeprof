## update
def baz
  [1, 1.0, "str"]
end

def foo
  x, y, z, w = baz
  x
end

def bar
  x = nil
  1.times do |_|
    x, y, z, w = baz
  end
  x
end

## assert
class Object
  def baz: -> [Integer, Float, String]
  def foo: -> Integer
  def bar: -> Integer?
end

## update
x, C, C::D::E, @iv, @@cv, $gv, ary[0], foo.bar = 1, 2, 3, 4, 5, 6, 7, 8
