## update: test.rb
def check(x)
  case x
  in y
    y
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> (Integer | String)
end

## update: test.rb
def check(x)
  case x
  in a, b, c, *rest
    [a, b, c, rest] # TODO: a, b, c stay untyped because x is not an array
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> [untyped, untyped, untyped, Array[untyped]]
end


## update: test.rb
def check(x)
  case x
  in { a:, b:, c:, **rest }
    [a, b, c, rest] # TODO!
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> [untyped, untyped, untyped, untyped]
end
