## update: test.rb
def cond?(x)
  x
end

def check_if(v)
  case v
  in [x] if cond?(x).even?
    x
  end
end

def check_unless(v)
  case v
  in [_, y] unless cond?(y).even?
    y
  end
end

check_if([1])
check_unless([:a, 1])

## diagnostics

## assert
class Object
  def cond?: (Integer) -> Integer
  def check_if: ([Integer]) -> Integer
  def check_unless: ([:a, Integer]) -> Integer
end
