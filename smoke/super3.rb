class Foo
  def self.new(a)
    super(a)
  end

  def initialize(a)
    @a = a
  end
end

Foo.new(1)

__END__
# Classes
class Foo
  @a: Integer
  def self.new: (Integer) -> Foo
  def initialize: (Integer) -> Integer
end
