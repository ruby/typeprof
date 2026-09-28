## update: test.rbs
class Gen[T]
  def self.create: () -> instance
end

class Object
  def accept: (Gen[Integer]) -> String
end

## update: test.rb
class Sub < Gen
end

def test
  accept(Sub.create)
end

## assert
class Sub < Gen
end
class Object
  def test: -> String
end
