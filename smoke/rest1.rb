def foo(a, *r, z)
  r[0]
end

foo(1, 2, "S", 3)
foo(1, 2, 3)
foo("a", "b", "c")

__END__
Object#foo :: (Integer, *Array[Integer | String], Integer) -> (Integer | String)
Object#foo :: (Integer, *Array[Integer], Integer) -> Integer
Object#foo :: (String, *Array[String], String) -> String