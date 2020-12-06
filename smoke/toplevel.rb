def foo(x)
  x
end

x = 1
foo(x)

__END__
# Classes
class Object
  private
  def foo: (Integer) -> Integer
end
