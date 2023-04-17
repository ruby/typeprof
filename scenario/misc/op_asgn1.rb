## update
def foo
  ary = [0]
  ary[0] ||= "str"
  ary
end

## assert
class Object
  def foo: -> [Integer | String]
end