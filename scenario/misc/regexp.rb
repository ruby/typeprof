## update
def check1
  /foo/
end
def check2
  /foo#{ 1 }bar/
end
def check3
  if /foo/ then end
end
def check4
  if /foo#{ 1 }/ then end
end

## assert
class Object
  def check1: -> Regexp
  def check2: -> Regexp
  def check3: -> nil
  def check4: -> nil
end
