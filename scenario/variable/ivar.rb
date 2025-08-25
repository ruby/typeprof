## update
class C
  def initialize(x)
    @x = 42
  end

  def foo(_)
    @x
  end
end

class D < C
  def bar(_)
    @x
    @x
    @x
  end
end

## assert
class C
  def initialize: (untyped) -> void
  def foo: (untyped) -> Integer
end
class D < C
  def bar: (untyped) -> Integer
end

## update
class C
  def initialize(x)
    @x = "42"
  end

  def foo(_)
    @x
  end
end

class D < C
  def bar(_)
    @x
  end
end

## assert
class C
  def initialize: (untyped) -> void
  def foo: (untyped) -> String
end
class D < C
  def bar: (untyped) -> String
end
