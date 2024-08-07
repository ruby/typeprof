## update
class Foo
  def to_a
    [1, "str"]
  end
end
def check
  [*Foo.new]
end

## assert
class Foo
  def to_a: -> [Integer, String]
end
class Object
  def check: -> Array[Integer | String]
end
