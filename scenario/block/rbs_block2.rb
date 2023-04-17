## update: test.rbs
class Object
  def foo: [X] { () -> Integer } -> String
end

## update: test.rb
def test
  ## TODO: we should report a wrong return type of block
  foo { "str" }
end

## assert: test.rb
class Object
  def test: -> String
end