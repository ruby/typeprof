## update
class << Time
  def foo = :ok
end

## assert
class Time
  def self.foo: -> :ok
end

## update
class Foo
  class << self
    def foo = :ok
  end
end

## assert
class Foo
  def self.foo: -> :ok
end

## update
class Bar; end

class Foo < Bar
  class << self
    def foo = :ok
  end
end

## assert
class Bar
end
class Foo < Bar
  def self.foo: -> :ok
end
