## update
class C
  def foo
    42
  end
end

class D < C
  alias bar foo
end

class E < D
  def bar
    super
  end
end

## assert
class C
  def foo: -> Integer
end
class D < C
end
class E < D
  def bar: -> Integer
end
