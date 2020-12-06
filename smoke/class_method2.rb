class Test
  class << self
    def foo(x)
      x
    end

    alias bar foo
  end
end

Test.foo(1)
Test.bar("str")
#Test.baz(:sym)
# Test#foo: (Integer) -> Integer

__END__
# Classes
class Test
  def self.foo: (Integer) -> Integer
  def self.bar: (String) -> String
end
