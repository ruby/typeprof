class Foo
  def initialize(a)
    @a = a
  end
  attr_reader :a

  attr_writer :b
  def get_b
    @b
  end

  attr_accessor :c
end

foo = Foo.new(1)
p(foo.a)
foo.b = 2
p(foo.get_b)
foo.c = 3
p(foo.c)

__END__
# Revealed types
#  smoke/attr.rb:16 #=> Integer
#  smoke/attr.rb:18 #=> Integer
#  smoke/attr.rb:20 #=> Integer
# Classes
class Foo
  @a : Integer
  @b : Integer
  @c : Integer
  def initialize : (Integer) -> Integer
  def a : () -> Integer
  def b= : (Integer) -> Integer
  def get_b : () -> Integer
  def c : () -> Integer
  def c= : (Integer) -> Integer
end
