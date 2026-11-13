## update
def foo(arr)
  result = []
  arr.each {|x| result << x * 2 }
  result
end

foo([1, 2, 3])

## assert
class Object
  def foo: ([Integer, Integer, Integer]) -> Array[Integer]
end

## update
def collect(arr)
  acc = []
  arr.each_with_index do |x, i|
    acc << [i, x]
  end
  acc
end

collect(["a", "b"])

## assert
class Object
  def collect: ([String, String]) -> Array[[Integer, String]]
end

## update
def foo
  ary = [1]
  ary << "str"
  ary
end

## assert
class Object
  def foo: -> Array[Integer | String]
end
