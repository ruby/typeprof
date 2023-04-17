## update: test.rb
def foo
end

foo

## update: test.rb
def foo
end

def foo # This is a new node (should have no prev_node)
end

foo

## assert: test.rb
class Object
  def foo: -> nil
  def foo: -> nil
end
