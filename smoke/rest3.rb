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
Object#foo :: (*Array[String]) -> NilClass
Object#bar :: (*Array[Integer | String]) -> NilClass
Object#baz :: (String, *Array[String]) -> NilClass
Object#qux :: (Integer, *Array[String]) -> NilClass
Object#corge :: (*Array[String], Integer) -> NilClass
Object#corge :: (*Array[Integer | String], String) -> NilClass
Object#grault :: (String, *Array[String], String) -> NilClass
Object#grault :: (String, String, *Array[String], String) -> NilClass