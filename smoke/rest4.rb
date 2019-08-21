def foo(*a)
end

a = ["str"] + ["str"]
foo(1, *a, :s)

__END__
Object#foo :: (*Array[Integer | String | Symbol]) -> NilClass
