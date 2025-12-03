## update
NonException = :foo

def foo(n)
  1
rescue NonException => e
  e
end

## diagnostics

## assert
NonException: :foo
class Object
  def foo: (untyped) -> Integer
end
