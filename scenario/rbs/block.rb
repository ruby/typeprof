## update: test.rbs
class Object
  def no_block: -> :ok
  def optional_block: ?{ (Integer) -> Integer } -> :ok
  def required_block: { (Integer) -> Integer } -> :ok
end

## update: test.rb
def test1
  no_block
end
def test2
  no_block { }
end
def test3
  optional_block
end
def test4
  optional_block { }
end
def test5
  required_block
end
def test6
  required_block { }
end

## assert
class Object
  def test1: -> :ok
  def test2: -> untyped
  def test3: -> :ok
  def test4: -> :ok
  def test5: -> untyped
  def test6: -> :ok
end