## update
def foo(**opts, &block)
  opts[:callback] = block
  opts
end

foo(key: 1) {}

## assert
class Object
  def foo: (**Integer) -> { key: Integer, callback: Proc }
end
