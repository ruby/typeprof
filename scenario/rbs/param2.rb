# update: test.rbs
class Object
  def foo: [U] (U) -> (U | :a)
  def bar: [U] (U, U) -> U
end

# update: test.rb
def test1
  foo("str")
end

def test2
  bar(1, "str")
end

# assert: test.rb
class Object
  def test1: -> (:a | String)
  def test2: -> (Integer | String)
end