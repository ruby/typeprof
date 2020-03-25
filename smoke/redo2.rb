def bar(x)
  x
end

def foo
  yield 42
end

foo do |x|
  bar(x)
rescue
  x = "str"
  redo if rand < 0.5
  42
end

__END__
# Classes
class Object
  foo : (&Proc[(Integer) -> (Integer | String)]) -> (Integer | String)
  bar : (Integer | String) -> (Integer | String)
end
