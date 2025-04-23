## update
def foo(n)
  raise if n != 0
  n.to_s
rescue StandardError => e
  e.message
end

foo(1)

## diagnostics

## assert
class Object
  def foo: (Integer) -> String
end
