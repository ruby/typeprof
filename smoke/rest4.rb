def foo(*a)
end

a = ["str"] + ["str"]
foo(1, *a, :s)

def bar(x, y, z)
end

a = ["str"] + ["str"]
bar(1, *a, :s)

__END__
# Classes
class Object
  foo : (*Array[Integer | String | Symbol]) -> NilClass
  bar : (Integer, String, String) -> NilClass
      | (Integer, String, Symbol) -> NilClass
      | (Integer, Symbol, String) -> NilClass
      | (Integer, Symbol, Symbol) -> NilClass
end
