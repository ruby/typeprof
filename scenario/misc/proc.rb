## update: test.rbs
class Object
  def foo: (^(Integer) -> void) -> void
end

## update: test.rb
def check(x)
end
f = ->(x) { check(x) } # TODO: this should pass an Integer to the method "check"? Is it possible?
foo(f)

## assert
class Object
  def check: (untyped) -> nil
end
