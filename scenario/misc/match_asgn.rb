## update
def check
  if /(?<a>foo)/ =~ "foo"
    a
  else
    1
  end
end

## assert
class Object
  def check: -> (Integer | String)
end
