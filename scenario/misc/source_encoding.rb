## update
def foo
  __ENCODING__
end

## assert
class Object
  def foo: -> Encoding
end
