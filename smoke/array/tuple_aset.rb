# update
def foo
  ary = [1, "str"]
  ary[0] = 1.0
  ary[0]
end

# assert
class Object
  def foo: () -> (Float | Integer)
end