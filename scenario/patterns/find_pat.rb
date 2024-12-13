## update: test.rb
def check(x)
  case x
  in *a, Integer, *b
    :foo
  in *a, String, *b
    :bar # TODO: this should be excluded
  else
    :zzz
  end
end

check([1].to_a)

## assert
class Object
  def check: (Array[Integer]) -> (:bar | :foo | :zzz)
end
