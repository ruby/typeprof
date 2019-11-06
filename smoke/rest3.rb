string_array = ["str"] + ["str"]

def foo(*r)
end
foo(*string_array)

def bar(*r)
end
bar(1, *string_array)

def baz(x, *r)
end
baz(*string_array)

def qux(x, *r)
end
qux(1, *string_array)

def corge(*r, z)
end
corge(1, *string_array)

def grault(a, o=1, *r, z)
end
grault(*string_array)

__END__
# Classes
class Object
  foo : (*Array[String]) -> NilClass
  bar : (*Array[Integer | String]) -> NilClass
  baz : (String, *Array[String]) -> NilClass
  qux : (Integer, *Array[String]) -> NilClass
  corge : (*Array[Integer | String], String) -> NilClass
        | (*Array[String], Integer) -> NilClass
  grault : (String, *Array[String], String) -> NilClass
         | (String, String, *Array[String], String) -> NilClass
end
