## update: test.rb
def check(x)
  case x
  in *a, Integer, *b
    :foo
  in *a, String, *b
    :bar # TODO: this should be excluded
  in [*, Integer, *b]
    :anon_left
  in [*a, Integer, *]
    :anon_right
  in [*, Integer, *]
    :anon_both
  else
    :zzz
  end
end

check([1].to_a)

## assert
class Object
  def check: (Array[Integer]) -> (:anon_both | :anon_left | :anon_right | :bar | :foo | :zzz)
end
