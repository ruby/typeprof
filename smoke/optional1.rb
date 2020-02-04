def foo(a, o1=1, o2=2, z)
  [a, o1, o2, z]
end

foo("A", "Z")
foo("A", "B", "Z")
foo("A", "B", "C", "Z")

__END__
# Classes
class Object
  foo : (String, ?String, ?String, String) -> ([String, Integer | String, Integer | String, String])
end
