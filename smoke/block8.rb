def bar
  baz do
    yield
  end
end

def baz
  yield
end

def foo
  a = 42
  bar do
    a = "str"
  end
  a
end

foo

__END__
# Classes
class Object
  foo : () -> (Integer | String)
  bar : () -> String
  baz : (&Proc[(&Proc[() -> String]) -> String]) -> String
end
