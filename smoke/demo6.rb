class Foo
  def foo=(x)
    @foo = x
  end

  def foo
    @foo
  end
end

Foo.new.foo = 1
Foo.new.foo = "str"
Foo.new.foo

__END__
Foo#@foo :: Integer | String
Foo#foo= :: (Integer) -> Integer
Foo#foo= :: (String) -> String
Foo#foo :: () -> (String | Integer)
