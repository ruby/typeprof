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
A#foo :: (Integer) -> NilClass
A#foo :: (String) -> NilClass
A#bar :: (Integer) -> NilClass
B#bar :: (String) -> NilClass
B#bar :: (NilClass) -> NilClass
A.class#test :: (Integer) -> NilClass
A.class#test :: (String) -> NilClass
