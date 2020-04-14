def bar(x)
end

def foo(x)
  x.tap {|n|
    bar(n)
  }
end

foo(1)

__END__
# Classes
class Object
  def bar : (Integer) -> NilClass
  def foo : (Integer) -> Integer
end
