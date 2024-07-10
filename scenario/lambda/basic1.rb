## update
def foo
  -> () { 1 }
end

## assert
class Object
  def foo: -> Proc
end

## update
def foo
  b = -> () { 1 }
  b.()
end

## assert
class Object
  def foo: -> untyped
end
