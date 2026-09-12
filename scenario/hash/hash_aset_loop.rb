## update
def foo(options)
  while options[:flag]
    options[:name] = "str"
  end
  nil
end

foo(Hash.new)

## assert
class Object
  def foo: (Hash[:flag, untyped]) -> nil
end
