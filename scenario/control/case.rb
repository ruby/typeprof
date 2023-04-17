# update
def foo(n)
  case n
  when 1
    1
  when 2
    "str"
  else
    1.0
  end
end

def bar(n)
  case n
  when 1
    1
  when 2
    "str"
  end
end

def baz(n)
  case n
  when 1
    1
  when 2
    "str"
  else
    raise
  end
end

# assert
class Object
  def foo: (untyped) -> (Float | Integer | String)
  def bar: (untyped) -> (Integer | String)?
  def baz: (untyped) -> (Integer | String)
end
