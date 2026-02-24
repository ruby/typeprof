## update
def foo
  x = "hello"
  for i in [1, 2, 3]
    x = 42
  end
  x
end

## assert
class Object
  def foo: -> (Integer | String)
end
