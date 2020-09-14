def f(a, b, c)
  ary = [nil]
  foo, bar, ary[0] = a, b, c
  ary[0]
end

f(:a, :b, :c)

__END__
# Classes
class Object
  def f : (:a, :b, :c) -> :c
end
