# update
def foo
  {
    a: 1,
    b: "str",
  }
end

def bar
  foo[:a]
end

def baz
  foo[:c] = 1.0
  foo[:c]
end

# assert
class Object
  def foo: () -> Hash[:a | :b, Float | Integer | String]
  def bar: () -> Integer
  def baz: () -> (Float | Integer | String)
end