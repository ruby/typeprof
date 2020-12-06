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

foo = Foo.new(:aaa)
foo.b = :bbb
foo.get_b
foo.c = :ccc

__END__
# Classes
class Foo
  attr_reader a: :aaa
  attr_writer b: :bbb
  attr_accessor c: :ccc
  def initialize: (:aaa) -> :aaa
  def get_b: -> :bbb
end
