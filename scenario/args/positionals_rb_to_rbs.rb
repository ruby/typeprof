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
  foo("str", *ary, 1, *ary, 2)
end
def test_ng1
  foo("str", "str")
end
def test_ng2
  foo("str", 1, 2, 3, "str")
end
def test_ng3
  foo("str", *ary, "str")
end

## assert
class Object
  def test_ok1: -> :ok
  def test_ok2: -> :ok
  def test_ok3: -> :ok
  def test_ok4: -> :ok
  def test_ok5: -> :ok
  def test_ng1: -> untyped
  def test_ng2: -> untyped
  def test_ng3: -> untyped
end

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
  def test_ng1: -> untyped
  def test_ng2: -> untyped
end

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
  def test_ng1: -> untyped
  def test_ng2: -> untyped
  def test_ng3: -> untyped
  def test_ng4: -> untyped
end

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
  def test_ng1: -> untyped
end
