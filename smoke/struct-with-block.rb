Foo = Struct.new(:foo) do
  def foo?
    !!foo
  end

  private

  def not_foo?
    !foo
  end
end
__END__
# Classes
class Foo < Struct[untyped]
  attr_accessor foo(): untyped
  def foo?: -> bool
  private
  def not_foo?: -> bool
end
