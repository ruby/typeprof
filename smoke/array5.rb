def foo
  a = [[nil]]
  a[0] = a
  a
end

foo

__END__
# Classes
class Object
  foo : () -> [any]
end
