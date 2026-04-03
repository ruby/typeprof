## update: test.rb
def foo(x)
  a = x
  # @type var a: Integer
  a + 1
end

## assert
class Object
  def foo: (untyped) -> Integer
end
