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
  def foo : -> []
  def bar : ([]) -> []
end
