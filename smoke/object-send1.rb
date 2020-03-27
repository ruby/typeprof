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
  foo : (Integer) -> Integer
  bar : (Integer) -> Integer
  dispatch : (:bar | :foo) -> Integer
end
