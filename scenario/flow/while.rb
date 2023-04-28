## update
def test(x)
  while x
    x + 1
  end
  x
end

test(nil)
test(1)

## assert
class Object
  def test: (Integer?) -> nil
end

## diagnostics