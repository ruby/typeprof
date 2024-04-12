## update
def foo(n)
  if n
    n = raise
    # TODO: if any statement returns a bot type, the whole block should also do so?
    1
  end
  n
end

def bar(n)
  if n
    n = raise
  end
  n
end

## assert
class Object
  def foo: (untyped) -> bot
  def bar: (untyped) -> untyped
end
