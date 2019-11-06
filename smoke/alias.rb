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
  foo : (Integer) -> Integer
  bar : (String) -> String
end
class Test
  baz : (Integer) -> Integer
  qux : (String) -> String
end
