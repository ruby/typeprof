class Foo
  def bar(n)
    :BAR
  end

  define_method(:foo) do |n|
    bar(:FOO)
  end
end

__END__
# Classes
class Foo
  def bar: (:FOO | untyped) -> :BAR
  def foo: (untyped) -> :BAR
end
