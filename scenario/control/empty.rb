## update
def foo(x)
  if x
  end
end

def bar(x)
  if x
  else
  end
end

def baz(x)
  while x
  end
end

## assert
class Object
  def foo: (untyped) -> nil
  def bar: (untyped) -> nil
  def baz: (untyped) -> nil
end
