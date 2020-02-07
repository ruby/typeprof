def foo(a)
  1.times do
    x, y = a
    return x
  end
end

foo([:a, :b, :c])

__END__
# Errors
<builtin>: [warning] complex parameter passing of block is not implemented
# Classes
class Object
  foo : ([:a, :b, :c]) -> :a
end
