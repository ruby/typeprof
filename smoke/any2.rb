def foo
  yield
end
def bar
  yield
  1
end

foo
bar

__END__
# Classes
class Object
  def foo : -> untyped
  def bar : -> Integer
end
