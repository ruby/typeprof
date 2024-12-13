## update: test.rb
def check(x)
  case x
  in y
    y # TODO!
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> untyped
end

## update: test.rb
def check(x)
  case x
  in a, b, c, *rest
    [a, b, c, rest] # TODO!
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> [untyped, untyped, untyped, untyped]
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
