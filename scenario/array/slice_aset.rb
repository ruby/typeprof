## update
def test
  a = [0] * 10
  a[0, 3] = [1, 2, 3]
  a[5, 3] = a[0, 3]
  a[0]
end

test

## assert
class Object
  def test: -> Integer
end
