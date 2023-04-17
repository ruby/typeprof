# update
def foo
  "foo#{ bar(1) }"
  "foo#{ bar(1) }baz#{ qux(1.0) }"
end

def bar(n)
  "bar"
end

def qux(n)
  "qux"
end

# assert
class Object
  def foo: -> String
  def bar: (Integer) -> String
  def qux: (Float) -> String
end