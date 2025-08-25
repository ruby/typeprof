## update: test.rb
class Foo
  def initialize(n)
    yield "string"
  end
end

def test
  Foo.new(1) do |x|
    return x
  end
end

## assert
class Foo
  def initialize: (Integer) { (String) -> bot } -> void
end
class Object
  def test: -> (Foo | String)
end
