## update: test.rbs
class C
  def foo: (C) -> C
  def bar: -> String
end

## update: test.rb
def check
  c = C.new
  @a = @b.bar
  @b = c.foo(@a)
end
