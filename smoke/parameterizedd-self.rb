class Object
  def foo
    self
  end
end

def bar(ary)
  ary.foo
end

bar([])

__END__
# Classes
class Object
  def foo: -> Array[untyped]

  private
  def bar: (Array[untyped] ary) -> Array[untyped]
end
