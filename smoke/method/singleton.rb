# update
class Foo
  def self.foo
    1
  end

  def self.bar
    foo
  end
end

def test
  Foo.foo
end

# assert
class Foo
  def self.foo: -> Integer
  def self.bar: -> Integer
end
class Object
  def test: -> Integer
end