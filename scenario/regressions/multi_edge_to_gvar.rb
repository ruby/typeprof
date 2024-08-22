## update
def check
  while true
    opt = 1
    if cond
      $foo = opt
    else
      $foo = opt
    end
  end
end

## assert
class Object
  def check: -> nil
end
