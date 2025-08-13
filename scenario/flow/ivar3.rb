## update
class Foo
  def initialize(x)
    @x = x
  end

  def accept_int(x) = nil
  def accept_str(x) = nil
  def accept_nil(x) = nil

  def foo
    if @x
      if @x.is_a?(String)
        accept_str(@x)
      else
        accept_int(@x)
      end
    else
      accept_nil(@x)
    end
  end
end

Foo.new(1)
Foo.new("")
Foo.new(nil)

## assert
class Foo
  def initialize: ((Integer | String)?) -> (Integer | String)?
  def accept_int: (Integer) -> nil
  def accept_str: (String) -> nil
  def accept_nil: (nil) -> nil
  def foo: -> nil
end
