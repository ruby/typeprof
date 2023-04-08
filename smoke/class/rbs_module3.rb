# update: test.rbs
module M2[X]
  def foo: -> X
end

module M[X]
  include M2[[X, X]]
end

class Foo
  include M[Integer]
end

# update: test.rb
def test
  Foo.new.foo
end

# assert: test.rb
class Object
  def test: -> [Integer, Integer]
end