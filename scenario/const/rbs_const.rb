## update
def foo
  RUBY_VERSION
end

def bar
  ENV["foo"]
end

## assert
class Object
  def foo: -> String
  def bar: -> String?
end