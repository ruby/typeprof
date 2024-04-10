## update
def check1
  /foo/
end
def check2
  /foo#{ 1 }bar/
end

## assert
class Object
  def check1: -> Regexp
  def check2: -> Regexp
end
