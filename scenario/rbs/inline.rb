## update
class C
  #: (Integer) -> Integer
  def foo(n)
    raise NotImplementedError.new # TODO: support "raise NotImplementedError"
  end

  def bar
    foo(1)
  end
end

## assert
class C
  def foo: (Integer) -> Integer
  def bar: -> Integer
end
