## update
def foo
  until true
    next
  end

  while false
    next
  end
end

## assert
class Object
  def foo: -> nil
end
