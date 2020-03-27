def ary
  [1, "str", :sym, 1.0]
end

def foo
  a, *rest, z = *ary
  [a, rest, z]
end

foo

__END__
# Classes
class Object
  ary : () -> [Integer, String, :sym, Float]
  foo : () -> [Integer, [String, :sym], Float]
end
