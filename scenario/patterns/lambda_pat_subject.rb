## update: test.rb
def pr(x)
  x
end

def check(x)
  case x
  in ->(i) { pr(i).foo }
    :a
  end
end

def check_arity(x)
  case x
  in ->(i, j) { true }
    :a
  end
end

check(0)
check_arity(0)

## diagnostics
(7,19)-(7,22): undefined method: Integer#foo
(14,5)-(14,22): wrong number of arguments (1 for 2)

## assert
class Object
  def pr: (Integer) -> Integer
  def check: (Integer) -> :a
  def check_arity: (Integer) -> :a
end
