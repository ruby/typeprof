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
Object#foo :: (Integer) -> Integer
Object#bar :: (String) -> String
Test#baz :: (Integer) -> Integer
Test#qux :: (String) -> String
