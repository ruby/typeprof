def foo(**kw)
  kw
end

foo(n: 42, s: "str")

__END__
# Classes
class Object
  foo : (**{:n=>Integer, :s=>String}) -> NilClass
end
