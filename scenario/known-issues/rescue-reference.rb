## update
def foo
  :normal
rescue => e
  e
end

## assert
class Object
  def foo: -> (:normal | StandardError)
end

## update
ERRORS = [ArgumentError, TypeError]

def foo
  :normal
rescue *ERRORS => e
  e
end

## assert
ERRORS: [singleton(ArgumentError), singleton(TypeError)]
class Object
  def foo: -> (:normal | ArgumentError | TypeError)
end
