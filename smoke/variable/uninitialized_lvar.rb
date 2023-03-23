# update
def foo
  x = x + 1
end

# assert
class Object
  def foo: -> untyped
end