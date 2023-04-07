# update: test.rbs
class Foo
  def foo: -> Integer
end

class Bar < Foo
end

# update: test.rb
def test
  Bar.new.foo
end

# assert: test.rb
class Object
  def test: -> Integer
end