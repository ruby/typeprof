# update
class Foo
  def foo(n)
    n
  end

  alias :bar :foo
end

Foo.new.bar(1)

# assert
class Foo
  def foo: (Integer) -> Integer
end