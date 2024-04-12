## update
def foo
  $x
end

$x ||= 1
$x ||= "str"

## assert
class Object
  def foo: -> (Integer | String)
end
