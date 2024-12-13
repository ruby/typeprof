## update: test.rb
def check(x)
  v = 1
  case x
  in ^v
    1
  in ^$v
    "str"
  in ^(1)
    1.0
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> (Float | Integer | String)
end
