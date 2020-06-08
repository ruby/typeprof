def foo(a)
  1.times do
    x, y = a
    return x
  end
end

foo([:a, :b, :c])

__END__
# Classes
class Object
  def foo : ([:a, :b, :c]) -> :a
end
