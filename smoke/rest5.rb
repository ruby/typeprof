def foo(*args)
  args
end

foo(42)
__END__
# Classes
class Object
  foo : (*Integer) -> Array[Integer]
end
