def foo(a, b, c)
  [a, b, c]
end

a = [1, "S", :s]
foo(*a)

#def bar(a, b, c)
#  [a, b,  d]
#end
#def baz(a, b, c)
#  [a, b,  d]
#end
#def qux(a, b, c)
#  [a, b,  d]
#end
#a = ["S", :s]
#bar(1, *a)

#a = ["S"] + [:s]
#baz(1, *a)

#a = [1, "S"]
#qux(*a, :s)

__END__
# Classes
class Object
  private
  def foo: (Integer, String, :s) -> [Integer, String, :s]
end
