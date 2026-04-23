## update
class C
  #: (*Integer) -> Integer
  def foo(x, y)
    x + y
  end
end

## assert
class C
  def foo: (Integer, Integer) -> Integer
end

## update
class C
  #: (*Integer) -> String
  def foo(x, y)
    x + y
  end
end

## diagnostics
(4,4)-(4,9): expected: String; actual: Integer
