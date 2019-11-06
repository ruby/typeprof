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
# Classes
class A
  foo : (Integer) -> NilClass
      | (String) -> NilClass
  bar : (Integer) -> NilClass
end
class B
  bar : (String) -> NilClass
end
