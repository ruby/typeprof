## update: test.rb
def check(x)
  x => Integer
  x
end

check(1)
check("str")

## assert
class Object
  def check: (Integer | String) -> (Integer | String)
end
