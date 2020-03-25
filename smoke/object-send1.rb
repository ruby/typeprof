def foo(x)
  x
end

def bar(x)
  x
end

def dispatch(mid)
  send(mid, 1)
end

dispatch(:foo)
dispatch(:bar)

__END__
# Classes
class Object
  dispatch : (:bar | :foo) -> Integer
  foo : (Integer) -> Integer
  bar : (Integer) -> Integer
end
