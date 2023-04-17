# update
def foo
  ary = [1, "str"]
  ary[0]
end

def bar
  ary = [1, "str"]
  i = 0
  ary[i]
end

# assert
class Object
  def foo: -> Integer
  def bar: -> (Integer | String)
end