## update
def foo(options)
  return if options[:skip]

  options[:name] = "str"
  bar(options)
  nil
end

def bar(options)
  options[:age] = 10
  nil
end

args = Hash.new
foo(args)

## assert
class Object
  def foo: (Hash[:skip, untyped]) -> nil
  def bar: (Hash[:name | :skip, String]) -> nil
end
