## update
def foo(n)
  n.to_s
end

foo(ARGV[0].to_i)

## assert
class Object
  def foo: (Integer) -> String
end
