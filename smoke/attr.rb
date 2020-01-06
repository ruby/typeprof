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
# Errors
smoke/attr.rb:16: [p] Integer
smoke/attr.rb:18: [p] Integer
smoke/attr.rb:20: [p] Integer
# Classes
class Foo
  @a : Integer
  @b : Integer
  @c : Integer
  initialize : (Integer) -> Integer
  a : () -> Integer
  b= : (Integer) -> Integer
  get_b : () -> Integer
  c= : (Integer) -> Integer
  c : () -> Integer
end
