## update
def foo
  if rand > 0.5
    raise
  end
rescue
  1
end

def bar
  raise
rescue
  1
end

## diagnostics

## assert
class Object
  def foo: -> Integer?
  def bar: -> Integer
end
