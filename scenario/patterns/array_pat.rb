## update: test.rb
class MyArray
end

def check(x)
  case x
  in 1, 2, 3
    :foo
  in [1, 2, 3, *]
    :bar
  in [String]
    :baz # TODO: this should be excluded
  in MyArray[1, 2, 3]
    :qux
  in [1,]
    :waldo
  else
    :zzz
  end
end

check([1].to_a)

## assert
class MyArray
end
class Object
  def check: (Array[Integer]) -> (:bar | :baz | :foo | :qux | :waldo | :zzz)
end
