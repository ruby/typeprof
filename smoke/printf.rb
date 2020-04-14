class F
  def foo
    printf("foo", "bar")
  end

  def bar
    a = %w(foo bar)
    printf(*a)
  end
end

F.new.foo
F.new.bar

__END__
# Classes
class F
  def foo : () -> NilClass
  def bar : () -> NilClass
end
