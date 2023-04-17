## update: test.rbs
class Foo[X]
  include Enumerable[[X, X]]
end

class Bar < Foo[Integer]
end

## update: test.rb
def test
  Bar.new.map {|x| x }
end

## assert: test.rb
class Object
  def test: -> Array[[Integer, Integer]]
end