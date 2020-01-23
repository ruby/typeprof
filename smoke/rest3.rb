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
  foo : (*String) -> NilClass
  bar : (*Integer | String) -> NilClass
  baz : (String, *String) -> NilClass
  qux : (Integer, *String) -> NilClass
  corge : (*Integer | String, Integer | String) -> NilClass
  grault : (String, ?String, *String, String) -> NilClass
end
