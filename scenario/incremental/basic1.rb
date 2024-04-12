## update: test0.rb
def foo(x)
  x * x
end

## assert: test0.rb
class Object
  def foo: (untyped) -> untyped
end

## update: test1.rb
def main
  foo(1)
end

## assert: test0.rb
class Object
  def foo: (Integer) -> Integer
end

## update: test1.rb
def main
  foo("str")
end

## assert: test0.rb
class Object
  def foo: (String) -> untyped
end
