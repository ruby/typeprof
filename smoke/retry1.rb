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
  foo : (Integer) -> (Integer | String)
  bar : (Integer | String) -> (Integer | String)
end
