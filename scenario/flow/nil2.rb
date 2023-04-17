# update
def foo(n)
  n = 1 unless n
  n
end

foo(1)
foo(nil)

# assert
class Object
  def foo: (Integer?) -> Integer
end