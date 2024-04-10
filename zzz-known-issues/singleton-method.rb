## update
class Foo
  def Foo.foo = :ok
  s = "Foo"
  def (s).foo = :ok
end

def check
  Foo.foo
end

## assert
class Foo
  def self.foo: -> :ok
  def self.???foo: -> :ok
end
class Object
  def check: -> :ok
end
