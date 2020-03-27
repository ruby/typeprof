def bar
  yield
end

def foo
  x = 42
  bar do
    x = "STR"
  end
  x
end

foo

__END__
# Classes
class Object
  bar : (&Proc[() -> String]) -> String
  foo : () -> (Integer | String)
end
