## update: test.rbs
class Foo
  def foo: (Hash) -> void
  def bar: -> Hash
end

## update: test.rb
Foo.new.foo({})
Foo.new.bar.map {}
