## update
def foo
  {}
  # RubyVM::AST.parse returns "nil" instead of neither NODE_NIL or NODE_RETURN
  return nil
end

## assert
class Object
  def foo: -> nil
end
