## update
def check(x)
end

def foo
  x = 1
  END { check(x) }
  x = "str"
end

## assert
class Object
  def check: (String) -> nil
  def foo: -> nil
end
