## update
def foo
end

def bar
  foo do |_|
    redo
  end
end

## assert
class Object
  def foo: -> nil
  def bar: -> nil
end
