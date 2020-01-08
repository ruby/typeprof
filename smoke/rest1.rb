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
# Classes
class Object
  foo : (:a, *Array[], :z) -> (Array[Integer | String])
      | (Integer, *Array[Integer | String], Integer) -> (Array[Integer | String])
      | (Integer, *Array[Integer], Integer) -> (Array[Integer | String])
      | (String, *Array[String], String) -> (Array[Integer | String])
  bar : (String, *Array[], String) -> (Array[String] | Array[])
      | (String, String, *Array[String], String) -> (Array[String] | Array[])
      | (String, String, *Array[], String) -> (Array[String] | Array[])
end