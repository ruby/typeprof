## update: test.rb
class Foo
  def initialize
    @x = nil
  end

  def get_x
    @x
  end
end

## update: test.rbs
class Foo
  @x: Integer
end

## assert: test.rb
class Foo
  def initialize: -> void
  def get_x: -> Integer
end
