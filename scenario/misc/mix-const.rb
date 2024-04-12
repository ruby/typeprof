## update
class C
end

## update
C = 1
def foo
  C
end

## assert
C: Integer
class Object
  def foo: -> Integer
end
