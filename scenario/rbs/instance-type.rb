## update: test.rbs
class Gen[T]
  def self.create: () -> instance
end

type gen[T] = Gen[T]

class Object
  def accept: (gen[Integer]) -> String
end

## update: test.rb
def test
  accept(Gen.create)
end

def raw
  Gen.create
end

## assert
class Object
  def test: -> String
  def raw: -> Gen[untyped]
end
