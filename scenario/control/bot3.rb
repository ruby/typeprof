# update
def foo
  n = raise
  n.bar
end

# assert
class Object
  def foo: -> untyped
end

# diagnostics