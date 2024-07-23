## update
def foo
  $foo = "str"
end

def bar
  $foo
end

def baz
  $VERBOSE
end

## assert
class Object
  def foo: -> String
  def bar: -> String
  def baz: -> bool?
end
