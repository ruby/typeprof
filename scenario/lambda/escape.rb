## update
def foo
  f = -> { return 1 }
  f.call
end

def bar
  g = -> { break "str" }
  g.call
end

def baz
  # The return of a block nested in a lambda leaves the lambda, not baz
  h = -> { [1].each { return :sym }; 1.0 }
  h.call
  nil
end

## assert
class Object
  def foo: -> Integer
  def bar: -> String
  def baz: -> nil
end
