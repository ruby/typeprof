# update
def foo
  0..1
end
def bar
  0..
end
def baz
  ..1
end
def qux
  nil..nil
end

# assert
class Object
  def foo: -> Range[Integer]
  def bar: -> Range[Integer?]
  def baz: -> Range[Integer?]
  def qux: -> Range[nil]
end