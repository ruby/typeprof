## update: test.rb
def check(x)
  x in Integer
end

check(1)
check("str")

## assert
class Object
  def check: (Integer | String) -> bool
end
