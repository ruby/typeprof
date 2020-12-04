class Foo
  attr_reader :foo
  def initialize
    @foo = [42]
  end
end

[Foo.new].flat_map(&:foo)

__END__
# Classes
class Foo
  attr_reader foo : Array[bot]
  def initialize : -> Array[bot]
end
