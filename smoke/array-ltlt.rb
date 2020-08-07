def foo
  a = []
  a << 1
  a << "str"
  a
end

foo
__END__
# Classes
class Object
  def foo : -> (Array[Integer | String])
end
