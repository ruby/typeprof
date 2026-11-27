## update
def foo
  x = 1
  defined?(x)
end

def bar
  defined?(@unknown)
end

## assert
class Object
  def foo: -> String?
  def bar: -> String?
end
