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
  def test2: -> :ok
  def test3: -> :ok
  def test4: -> :ok
  def test5: -> :ok
  def test6: -> :ok
end

## diagnostics
(5,2)-(5,10): block is not expected
(11,2)-(11,20): expected: Integer; actual: nil
(14,2)-(14,16): block is expected
(17,2)-(17,20): expected: Integer; actual: nil
