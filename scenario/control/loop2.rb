## update: test.rb
def test
  a = "foo"
  while true
    a = a.sum
  end
end

## assert
class Object
  def test: -> nil
end

## diagnostics
(4,10)-(4,13): undefined method: Integer#sum
