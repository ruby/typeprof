def foo(a)
  a * 3
end

def bar(a)
  a * "join"
end

foo([1, 2, 3])
bar([1, 2, 3])

__END__
# Classes
class Object
  private
  def foo: ([Integer, Integer, Integer]) -> Array[Integer]
  def bar: ([Integer, Integer, Integer]) -> String
end
