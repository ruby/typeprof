## update: test.rbs
class C
  def foo: (Integer) -> :int
         | (String) -> :str
end

## update: test.rb
class D1 < C
  def foo
    super(1)
  end
end

class D2 < C
  def foo
    super("str")
  end
end

## assert
class D1 < C
  def foo: -> :int
end
class D2 < C
  def foo: -> :str
end

## update
class StringifyKeyHash < Hash
  def [](key)
    super(key.to_s)
  end
end

## assert
class StringifyKeyHash < Hash
  def []: (untyped) -> untyped
end
