## update: test.rbs
class Foo
  def get_ints: () -> Array[Integer]
end

## update: test.rb
class Foo
  def test_masgn
    a, b, c = get_ints
    [a, b, c]
  end

  def test_star
    a, *rest = get_ints
    rest
  end
end

## assert: test.rb
class Foo
  def test_masgn: -> [Integer, Integer, Integer]
  def test_star: -> Array[Integer]
end
