## update
def foo(x)
  [*x]
end

foo([:int])
foo(:sym)

## assert
class Object
  def foo: (Array[:int] | :sym) -> Array[:int | :sym]
end
