def foo(*a)
end

a = ["str"] + ["str"]
foo(1, *a, :s)

def bar(x, y, z)
end

a = ["str"] + ["str"]
bar(1, *a, :s)

__END__
Object#foo :: (*Array[Integer | String | Symbol]) -> NilClass
Object#bar :: (Integer, Symbol, Symbol) -> NilClass
Object#bar :: (Integer, Symbol, String) -> NilClass
Object#bar :: (Integer, String, Symbol) -> NilClass
Object#bar :: (Integer, String, String) -> NilClass
