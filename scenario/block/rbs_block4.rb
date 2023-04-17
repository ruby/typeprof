## update: test.rbs
class Object
  def foo: [R] { (Integer) -> R } -> R
end

## update: test.rb
def test
  foo {|x| x.to_s }
end

def test2
  [1, "str", 1.0].map {|x| [x, x.to_s] }
end

## assert: test.rb
class Object
  def test: -> String
  def test2: -> Array[[Float | Integer | String, String]]
end