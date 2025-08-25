## update: test.rb
class Foo
  def initialize(n)
  end
end

class Bar
  def initialize(n)
  end
end

def my_new(klass)
  klass.new(1)
end

my_new(Foo)
my_new(Bar)

## assert
class Foo
  def initialize: (Integer) -> void
end
class Bar
  def initialize: (Integer) -> void
end
class Object
  def my_new: (singleton(Bar) | singleton(Foo)) -> (Bar | Foo)
end
