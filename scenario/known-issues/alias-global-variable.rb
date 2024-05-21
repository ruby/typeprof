## update
def foo
  $v = :ok
end

def bar
  alias $new_v $v
  $new_v
end

## assert
class Object
  def foo: -> :ok
  def bar: -> :ok
end
