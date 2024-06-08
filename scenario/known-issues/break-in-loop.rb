## update: test.rb
def bar
  yield
  nil
end

def foo
  bar do
    break :a
    until true
      break :b
    end
    break :c
  end
end

## assert: test.rb
class Object
  def bar: { () -> (:a | :c) } -> nil
  def foo: -> nil
end

## update: test.rb
def foo
  until true
    break :a
  end
end

## assert: test.rb
class Object
  def foo: -> :a
end
