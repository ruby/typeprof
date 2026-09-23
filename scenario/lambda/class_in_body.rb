## update
REG = {}
REG["a"] = -> {
  class Foo
    def bar = 1
  end
}
def foo = Foo.new.bar

## assert
REG: {  }
class Foo
  def bar: -> Integer
end
class Object
  def foo: -> Integer
end
