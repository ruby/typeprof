def foo(a, *r, z)
  r
end

foo(1, 2, "S", 3)
foo(1, 2, 3)
foo("a", "b", "c")
foo(:a, :z)

def bar(a, o=1, *r, z)
  r
end

bar("A", "Z")
bar("A", "B", "Z")
bar("A", "B", "C", "Z")
bar("A", "B", "C", "D", "Z")
bar("A", "B", "C", "D", "E", "Z")

__END__
Object#foo :: (Integer, *Array[Integer | String], Integer) -> Array[Integer | String]
Object#foo :: (Integer, *Array[Integer], Integer) -> Array[Integer]
Object#foo :: (String, *Array[String], String) -> Array[String]
Object#foo :: (Symbol, *Array[], Symbol) -> Array[]
Object#bar :: (String, *Array[], String) -> Array[]
Object#bar :: (String, String, *Array[], String) -> Array[]
Object#bar :: (String, String, *Array[String], String) -> Array[String]