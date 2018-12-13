class Foo
  def foo=(x)
    @foo = x
  end

  def foo
    @foo
  end
end

def log(x)
end

Foo.new.foo = 1
log(Foo.new.foo)
Foo.new.foo = "str"
log(Foo.new.foo)

__END__
Foo#@foo :: Integer | String
Foo#foo= :: (Integer) -> Integer
Foo#foo= :: (String) -> String
Foo#foo :: () -> (Integer | String)
Object#log :: (Integer) -> NilClass
Object#log :: (String) -> NilClass
