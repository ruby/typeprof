class Foo
  class << self
    alias [] new
  end

  def initialize(a, b, c)
    @a, @b, @c = a, b, c
  end
end

Foo[:x, :y, :z]
__END__
# Classes
class Foo
  @a: :x
  @b: :y
  @c: :z
  def initialize: (:x, :y, :z) -> [:x, :y, :z]
end
