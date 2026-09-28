## update
# The parameter of an empty lambda is its own, not the enclosing x
def outer_local
  x = 1
  f = ->(x) { }
  f.call("str")
  x
end

def check(v) = v

# An empty lambda returns nil, not what the enclosing method returns
def enclosing_return(c)
  return :sym if c
  f = -> { }
  check(f.call)
  nil
end

# An empty lambda returns nil, not what the enclosing block breaks with
def enclosing_break
  [1].each do
    g = -> { }
    check(g.call)
    break "str"
  end
  nil
end

## assert
class Object
  def outer_local: -> Integer
  def check: (nil) -> nil
  def enclosing_return: (untyped) -> :sym?
  def enclosing_break: -> nil
end
