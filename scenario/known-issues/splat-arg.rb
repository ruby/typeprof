## update
class Foo
  def check(*args)
    args # This should be an Array[Integer], but currently it's an Integer
  end

  def foo
    check(1)
  end
end

## assert
class Foo
  def check: (*Integer) -> Array[Integer]
  def foo: -> Integer
end
