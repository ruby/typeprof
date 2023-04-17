# update
def foo(n)
  raise "foo" unless n
  n
end

foo(1)
foo(nil)

# assert
class Object
  def foo: (Integer?) -> Integer
end