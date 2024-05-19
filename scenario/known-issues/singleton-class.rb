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
