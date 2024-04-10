## update
def foo
  [1].zip(["str"]) do |x, y|
    return x
  end
  nil
end

## assert
class Object
  def foo: -> Integer?
end
