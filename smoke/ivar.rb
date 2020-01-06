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
# Classes
class Foo
  @foo : Integer | Integer | String
  foo= : (Integer) -> (Integer | String)
       | (String) -> (Integer | String)
  foo : () -> (Integer | String)
end
class Object
  log : (Integer) -> NilClass
      | (String) -> NilClass
end