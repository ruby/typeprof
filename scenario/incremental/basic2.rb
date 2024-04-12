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
  x + 1.0
end

def main
  foo(2)
end

## assert
class Object
  def foo: (Integer) -> Float
  def main: -> Float
end
