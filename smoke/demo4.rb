# user-defined classes
class A
  def foo(x)
    bar(x)
  end

  def bar(x)
  end
end

class B < A
  def bar(x)
  end
end
A.new.foo(1)
B.new.foo("str")

__END__
A#foo :: (Integer) -> NilClass
A#foo :: (String) -> NilClass
A#bar :: (Integer) -> NilClass
B#bar :: (String) -> NilClass
