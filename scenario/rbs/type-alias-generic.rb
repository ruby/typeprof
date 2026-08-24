## update: test.rbs
type list[T] = Array[T] | _ToAry[T]

class Object
  def take_list: [U] (list[U]) -> Array[U]
end

## update: test.rb
def test
  take_list([1])
end

## assert
class Object
  def test: -> Array[Integer]
end
