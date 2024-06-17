## update
k = Time
class << k
  def foo = :ok
end

## assert
class Time
  def self.foo: -> :ok
end

## update
class Foo
  class << self
    def self.bar = :ok
  end
end

## assert
class Foo
end
