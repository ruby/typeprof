## update
def foo(x)
  unless x.nil?
    x.to_sym
  end
end
foo(nil)
foo("hello")

## assert
class Object
  def foo: (String?) -> Symbol?
end
