def foo(a, *r, z)
  r
end

foo(1, 2, "S", 3)
foo(1, 2, 3)
foo("a", "b", "c")
foo(:a, :z)

__END__
Object#foo :: (Integer, *Array[Integer | String], Integer) -> Array[Integer | String]
Object#foo :: (Integer, *Array[Integer], Integer) -> Array[Integer]
Object#foo :: (String, *Array[String], String) -> Array[String]
Object#foo :: (Symbol, *Array[], Symbol) -> Array[]