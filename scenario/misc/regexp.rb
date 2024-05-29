## update
def check1
  /foo/
end
def check2
  /foo#{ 1 }bar/
end
def check3
  if /foo/
    :then
  else
    :else
  end
end
def check4
  if /foo#{ 1 }/
    :then
  else
    :else
  end
end

## assert
class Object
  def check1: -> Regexp
  def check2: -> Regexp
  def check3: -> (:else | :then)
  def check4: -> (:else | :then)
end
