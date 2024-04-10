## update: test.rb
class Foo
  def initialize(n)
    yield "string", 1.0
    nil
  end
end

Foo.new(1) do |x|
  1
end

Foo.new(1) do |x, y|
  "str"
end

## assert
class Foo
  def initialize: (Integer) { (String, Float) -> (Integer | String) } -> nil
end
