# update
def foo
  1.0.phase
end

# assert
class Object
  def foo: -> (Float | Integer)
end