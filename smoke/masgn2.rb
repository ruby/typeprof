def ary
  [1, "str", :sym, nil]
end

def foo
  a, *rest, z = *ary
  [a, rest, z]
end

foo

__END__
Object#foo :: () -> [Integer, [String, Symbol], NilClass]
Object#ary :: () -> [Integer, String, Symbol, NilClass]
