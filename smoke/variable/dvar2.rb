# update
def foo(x)
  x = "str"
  1.times do |_|
    x = 42
  end
  x
end

def bar(x)
  x = "str"
  1.times do |x|
    x = 42
  end
  x
end

# assert
class Object
  def foo: (Integer | String) -> (Integer | String)
  def bar: (String) -> String
end