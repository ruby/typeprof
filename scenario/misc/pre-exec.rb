## update
def check(x)
end

def check2(x)
end

y = "str"

BEGIN {
  def hello = "hello"
  x = 1
  y = 1
}

check(x)
check2(y)

## assert
class Object
  def check: (Integer) -> nil
  def check2: (String) -> nil
  def hello: -> String
end
