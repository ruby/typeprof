## update
def foo(ary)
  case ary
  in [a]
    a
  end
end
foo([1])

## assert
class Object
  def foo: ([Integer]) -> Integer
end

## update
def foo(ary)
  case ary
  in [a]
    a.to_s
  end
end
foo([1])

## assert
class Object
  def foo: ([Integer]) -> String
end
