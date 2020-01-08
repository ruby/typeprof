def ary
  [1, "str", :sym, nil]
end

def foo
  a, *rest, z = *ary
  [a, rest, z]
end

foo

__END__
# Classes
class Object
  foo : () -> [Integer, [String, :sym], NilClass]
  ary : () -> [Integer, String, :sym, NilClass]
end