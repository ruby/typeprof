# update
def foo(x)
  return if x
  "str"
end

def bar(x)
  return 1 if x
  "str"
end

def baz(x)
  1.times do |_|
    return 1
  end
  "str"
end

# assert
class Object
  def foo: (untyped) -> String?
  def bar: (untyped) -> (Integer | String)
  def baz: (untyped) -> (Integer | String)
end