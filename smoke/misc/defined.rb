# update
def foo
  if defined?($x)
    1
  else
    "str"
  end
end

# assert
class Object
  def foo: -> (Integer | String)
end