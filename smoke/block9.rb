def foo(&b)
  b = 1
  b
end

foo { }

__END__
# Classes
class Object
  foo : () -> Integer
end
