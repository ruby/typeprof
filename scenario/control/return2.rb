## update
def foo
  return 1, 2
end

## assert
class Object
  def foo: -> [Integer, Integer]
end
