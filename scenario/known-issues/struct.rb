## update: test.rb
Foo = Struct.new(:foo) do
  def foo?
    !!foo
  end

  private

  def not_foo?
    !foo
  end
end

## assert: test.rb
class Foo < Struct[untyped]
  def foo: -> untyped
  def foo?: -> bool
  private
  def not_foo?: -> bool
end
