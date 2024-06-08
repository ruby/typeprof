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

## update
def bar
  yield
  nil
end

def foo
  bar do
    next :a
    until true
      next :b
    end
    next :c
  end
end

## assert
class Object
  def bar: { () -> (:a | :c) } -> nil
  def foo: -> nil
end
