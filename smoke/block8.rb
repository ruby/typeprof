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
Object#foo :: () -> (Integer | String)
Object#bar :: () -> String
Object#baz :: (&Proc[(&Proc[() -> String]) -> String]) -> String
