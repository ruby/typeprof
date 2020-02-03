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
  foo : () -> [Integer, [String, :sym], Float]
  ary : () -> [Integer, String, :sym, Float]
end
