## update: test.rbs
class Object
  def foo: [X] { () -> X } -> X
end

## update: test.rb
def test
  foo { 1 }
end

## assert: test.rb
class Object
  def test: -> Integer
end
