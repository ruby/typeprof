# update
class C
  def foo=(x)
    @foo = x
  end

  def foo
    @foo
  end
end

f = C.new
f.foo = 42

# assert
class C
  def foo=: (Integer) -> Integer
  def foo: -> Integer
end