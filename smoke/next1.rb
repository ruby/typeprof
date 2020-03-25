def bar(n)
  n
end

def foo
  yield 42
end

foo do |x|
  bar(x)
  next "str"
  no_method
end

__END__
# Classes
class Object
  foo : (&Proc[(Integer) -> String]) -> String
  bar : (Integer) -> Integer
end
