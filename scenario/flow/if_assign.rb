## update
def foo(x)
  if (y = x)
    y.to_sym
  end
end
foo(nil)
foo("hello")

## assert
class Object
  def foo: (String?) -> Symbol?
end

## update
def foo(x, z)
  if x && (y = z)
    y.to_sym
  end
end
foo(true, "hello")
foo(true, nil)
foo(false, nil)

## assert
class Object
  def foo: (bool, String?) -> Symbol?
end

## update
def foo(z)
  if (y = z) && y.length > 0
    y.to_sym
  end
end
foo("hello")
foo(nil)

## assert
class Object
  def foo: (String?) -> Symbol?
end
