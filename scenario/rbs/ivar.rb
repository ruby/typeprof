## update: test.rbs
class Foo
  @foo: String
  self.@foo: Integer
end

## update: test.rb
class Foo
  def check
    @foo
  end
  def self.check
    @foo
  end
end

## assert
class Foo
  def check: -> String
  def self.check: -> Integer
end
