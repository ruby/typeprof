## update: test.rbs
class Foo[X]
  def self.gen: -> Foo[Integer]
  def dup_like: -> Foo[X]
end

## update: test.rb
class Bar
  def test
    @elem = Foo.gen
    @elem = @elem.dup_like
  end
end

## assert
class Bar
  def test: -> Foo[Integer]
end