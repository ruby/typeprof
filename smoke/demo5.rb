class A
  def self.foo(x); "str"; end
end
class B < A
end
A.foo(1)
B.foo(Integer)

__END__
A.class#foo :: (Integer) -> String
A.class#foo :: (Integer.class) -> String
