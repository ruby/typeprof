def foo(n)
  n
end

def bar
  foo(1)
end

__END__
# Classes
class Object
  def foo : (Integer | any) -> (Integer | any)
  def bar : -> (Integer | any)
end
