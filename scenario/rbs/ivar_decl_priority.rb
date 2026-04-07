## update: test.rbs
class Base
end

class Child < Base
  @x: Integer
end

## update: test.rb
class Base
  def initialize
    @x = nil
  end
end

class Child < Base
  def initialize
    super
    @x = 1
  end

  def get_x
    @x
  end
end

## assert
class Base
  def initialize: -> void
end
class Child < Base
  def initialize: -> void
  def get_x: -> Integer
end
