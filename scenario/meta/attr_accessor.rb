# update
class Foo
  attr_accessor :x

  def foo
    x
  end
end

foo = Foo.new
foo.x = "str"

# assert
class Foo
  def x: -> String
  def x=: (String) -> String
  def foo: -> String
end