## update: test.rb
def check(x)
  case x
  in Integer
    :int
  in String
    :str
  end
end

check(1)
check("foo")

## assert
class Object
  def check: (Integer | String) -> (:int | :str)
end
