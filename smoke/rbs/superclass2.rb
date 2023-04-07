# update: test.rbs
class Foo[X]
  def foo: -> X
end

class Bar < Foo[[Integer, String]]
end

# update: test.rb
def test
  Bar.new.foo
end

# assert: test.rb
class Object
  def test: -> [Integer, String]
end