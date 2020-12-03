class Foo
  attr_reader :foo
  def initialize(foo)
    @foo = foo
  end
end

def log
  [Foo.new(42)].map(&:foo)
end
