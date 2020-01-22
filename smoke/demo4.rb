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
  foo : (Integer | String) -> NilClass
  bar : (Integer | String) -> NilClass
end
class B
  bar : (Integer | String) -> NilClass
end
