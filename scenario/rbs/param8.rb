## update: test.rbs
class Foo[X]
  def initialize: (X) -> void
  @x: X
  # TODO: Currently, handling a type variable is immature.
  # Unless the explicit declaration of get_x, a bare type variable X is leaked.
  # A naive fix will bring huge performance penalties, so we need a good solution.
  def get_x: -> X
end

## update: test.rb
class Foo
  def initialize(x)
    @x = x
  end

  def get_x
    @x
  end
end

def check
  Foo.new(1).get_x
end

## assert
class Foo
  def initialize: (var[X]) -> (Object | var[X])
  def get_x: -> var[X]
end
class Object
  def check: -> Integer
end
