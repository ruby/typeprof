## update
def foo(x)
  x + 1
end

def main
  foo(2)
end

## assert
class Object
  def foo: (Integer) -> Integer
  def main: -> Integer
end

## update
def foo(x)
  x + 1
end

def main
  foo("str")
end

## assert
class Object
  def foo: (String) -> untyped
  def main: -> untyped
end
