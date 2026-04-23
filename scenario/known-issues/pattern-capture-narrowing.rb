## update
def check(a)
  case a
  in Integer => n
    n + 1
  in String => s
    s.upcase
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> (Integer | String)?
end

## update
def check(a)
  case a
  in [Integer => n, String => s]
    [n, s]
  end
end

check([42, "foo"])

## assert
class Object
  def check: ([Integer, String]) -> [Integer, String]?
end
