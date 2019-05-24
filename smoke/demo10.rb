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
Object#foo :: () -> (Integer | String)
Object#bar :: (&Proc[() -> String]) -> String
