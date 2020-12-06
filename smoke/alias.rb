def foo(x)
  x
end

alias bar foo

class Test
  def baz(x)
    x
  end

  alias qux baz
end

foo(1)
bar("str")
Test.new.baz(1)
Test.new.qux("str")

__END__
# Classes
class Object
  private
  def foo: (Integer) -> Integer
  def bar: (String) -> String
end

class Test
  def baz: (Integer) -> Integer
  def qux: (String) -> String
end
