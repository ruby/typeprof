## update
def check
  if rand < 0.5
    a = [].map {|arg| 1 }
  else
    a = []
  end
  a << :foo
end

## assert
class Object
  def check: -> (Array[Integer] | [])
end
