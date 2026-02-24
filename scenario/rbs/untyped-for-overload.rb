## update: test.rbs
class C
  def foo: (:a) -> :A
         | (:b) -> :B
end

## update: test.rb
def check
  C.new.foo($untyped)
end

## assert
class Object
  def check: -> (:A | :B)
end
