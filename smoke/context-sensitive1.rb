def foo(x)
  x
end

x = nil
foo(x || 1)

__END__
# Classes
class Object
  foo : (Integer) -> Integer
end
