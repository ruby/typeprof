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
  def foo: (String) -> String
end

## diagnostics: test0.rb
(2,4)-(2,5): wrong type of arguments
