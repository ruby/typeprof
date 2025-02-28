## update: test.rbs
class Object
  def foo: (String, *Integer) -> :ok
end

## update: test.rb
def test_ok1
  foo("str")
end
def test_ok2
  foo("str", 1)
end
def test_ok3
  foo("str", 1, 2, 3)
end
def test_ok4
  ary = [1].to_a
  foo("str", *ary)
end
def test_ok5
  foo("str", *$untyped, 1, *$untyped, 2)
end
def test_ng1
  foo("str", "str")
end
def test_ng2
  foo("str", 1, 2, 3, "str")
end
def test_ng3
  foo("str", *$untyped, "str")
end

## assert
class Object
  def test_ok1: -> :ok
  def test_ok2: -> :ok
  def test_ok3: -> :ok
  def test_ok4: -> :ok
  def test_ok5: -> :ok
  def test_ng1: -> :ok
  def test_ng2: -> :ok
  def test_ng3: -> :ok
end

## diagnostics
(18,2)-(18,5): wrong type of arguments
(21,2)-(21,5): wrong type of arguments
(24,2)-(24,5): wrong type of arguments

## update: test.rbs
class Object
  def foo: (String, ?Integer) -> :ok
end

## update: test.rb
def test_ok1
  foo("str")
end
def test_ok2
  foo("str", 1)
end
def test_ng1
  foo("str", 1, 2)
end
def test_ng2
  ary = [1].to_a
  foo("str", *ary)
end

## assert
class Object
  def test_ok1: -> :ok
  def test_ok2: -> :ok
  def test_ng1: -> :ok
  def test_ng2: -> :ok
end

## diagnostics
(8,2)-(8,5): wrong type of arguments
(12,2)-(12,5): wrong type of arguments

## update: test.rbs
class Object
  def foo: (String, ?Float, *Integer) -> :ok
end

## update: test.rb
def test_ok1
  foo("str")
end
def test_ok2
  foo("str", 1.0)
end
def test_ok3
  foo("str", 1.0, 1, 2, 3)
end
def test_ok4
  ary = [1].to_a
  foo("str", 1.0, *ary, 2, *ary, 3)
end
def test_ng1
  foo("str", 1)
end
def test_ng2
  foo("str", 1, 2, 3)
end
def test_ng3
  ary = [1].to_a
  foo("str", *ary)
end
def test_ng4
  ary = [1].to_a
  foo(*ary)
end

## assert
class Object
  def test_ok1: -> :ok
  def test_ok2: -> :ok
  def test_ok3: -> :ok
  def test_ok4: -> :ok
  def test_ng1: -> :ok
  def test_ng2: -> :ok
  def test_ng3: -> :ok
  def test_ng4: -> :ok
end

## diagnostics
(15,2)-(15,5): wrong type of arguments
(18,2)-(18,5): wrong type of arguments
(22,2)-(22,5): wrong type of arguments
(26,2)-(26,5): wrong type of arguments

## update: test.rbs
class Object
  def foo: (String, ?Float, *(Float | Integer)) -> :ok
end

## update: test.rb
def test_ok1
  ary = [1.0].to_a
  foo("str", *ary, 1.0)
end
def test_ok2
  ary = [1].to_a
  foo("str", 1.0, *ary)
end
def test_ng1
  ary = [1].to_a
  foo("str", *ary, 1)
end

## assert
class Object
  def test_ok1: -> :ok
  def test_ok2: -> :ok
  def test_ng1: -> :ok
end

## diagnostics
(11,2)-(11,5): wrong type of arguments
