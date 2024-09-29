## update
def foo
  n = 3
  if (n==2)..(n==2)
    # flip_flop_node can not become a return value because it is only available in condition.
  end
end

## assert
class Object
  def foo: -> nil
end