## update: test.rb
class MyHash
end

def check(x)
  case x
  in { a: Integer }
    :foo
  in { a: String, ** }
    :bar # TODO: this should be excluded
  in { a: }
    :baz
  in MyHash[a: Integer]
    :qux
  in { **nil }
    :no_kw
  else
    :zzz
  end
end

check({ a: 42 })

## assert
class MyHash
end
class Object
  def check: ({ a: Integer }) -> (:bar | :baz | :foo | :no_kw | :qux | :zzz)
end
