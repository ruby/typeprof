## update
def foo(v)
  if v
    [v]
  else
    v
  end
end

foo(true)
foo(false)

## assert
class Object
  def foo: (bool) -> ([true] | false)
end

## update
def foo(v)
  v ? 1 : v
end

foo(true)
foo(false)

## assert
class Object
  def foo: (bool) -> (Integer | false)
end
