class A
  def foo(x)
    bar(x)
  end

  def bar(x)
  end

  def self.test(x)
  end
end

class B < A
  def bar(x)
  end
end

A.new.foo(1)
B.new.foo("str")
B.new.bar(nil)
A.test(1)
B.test("str")

__END__
# Classes
class A
  foo : (Integer) -> NilClass
      | (String) -> NilClass
  bar : (Integer) -> NilClass
      | (String) -> NilClass
  self.test : (Integer) -> NilClass
            | (String) -> NilClass
end
class B
  bar : (Integer) -> NilClass
      | (NilClass) -> NilClass
      | (String) -> NilClass
end