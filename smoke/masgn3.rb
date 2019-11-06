def foo
  a, b, c = 42
  [a, b, c]
end

foo

__END__
# Classes
class Object
  foo : () -> [Integer, NilClass, NilClass]
end
