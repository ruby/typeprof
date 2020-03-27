def foo(x)
  42
end

def bar
  x = 1
  x = "str"
  x = :sym
ensure
  foo(x)
end

bar

__END__
# Classes
class Object
  foo : (:sym | Integer | NilClass | String) -> Integer
  bar : () -> :sym
end
