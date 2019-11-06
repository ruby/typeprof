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
  foo : () -> (Integer | String)
  bar : (&Proc[() -> String]) -> String
end
