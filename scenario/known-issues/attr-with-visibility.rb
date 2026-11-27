## update
class Foo
  def initialize(name)
    @name = name
  end

  private attr_reader :name

  def label = name
end

Foo.new("foo").label

## assert
class Foo
  def initialize: (String) -> void
  def name: -> String
  def label: -> String
end

## update
class Foo
  def initialize(count)
    @count = count
  end

  public attr_accessor :count
end

foo = Foo.new(1)
foo.count = 2

## assert
class Foo
  def initialize: (Integer) -> void
  def count: -> Integer
  def count=: (Integer) -> Integer
end
