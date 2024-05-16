## update
def foo
  -> () { 1 }
end

## assert
class Object
  def foo: -> Proc
end
