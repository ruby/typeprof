## update: test.rbs
class C
  def foo: ([String, Integer]) -> :tuple
         | (String) -> :str
end

## update: test.rb
def check(unknown)
  C.new.foo(unknown)
end

## diagnostics: test.rb

## assert
class Object
  def check: (untyped) -> untyped
end
