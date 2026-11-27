## update
def foo(h)
  case h
  in { v: x }
    x
  end
end

def bar(h)
  case h
  in { v: }
    v
  end
end

foo({ v: 1 })
bar({ v: "str" })

## assert
class Object
  def foo: ({ v: Integer }) -> Integer
  def bar: ({ v: String }) -> String
end
