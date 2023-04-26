## update
def foo
  s = Set[]
  s << 42 # special handling of Set#<< is not implemented
  s
end

## assert
class Object
  def foo: -> Set[Integer]
end