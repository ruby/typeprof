# update
class C
  #: (Integer) -> Integer
  def foo(n)
    raise NotImplementedError
  end

  def bar
    foo(1)
  end
end

# assert
class C
  def foo: (Integer) -> untyped
  def bar: -> Integer
end