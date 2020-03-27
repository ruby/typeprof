def bar(x)
  x
end

def foo(x)
  bar(x)
rescue
  x = "str"
  retry
  42
end

foo(42)

__END__
# Classes
class Object
  bar : (Integer | String) -> (Integer | String)
  foo : (Integer) -> (Integer | String)
end
