## update
def foo(n)
  if n
    x = n
  else
    x = "str"
  end
  x
end

foo(1)
foo(nil)

## assert
class Object
  def foo: (Integer?) -> (Integer | String)
end
