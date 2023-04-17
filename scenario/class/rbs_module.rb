# update
def foo
  rand # Kernel#rand
end

# assert
class Object
  def foo: -> Float
end